cd ${CODEBUILD_SRC_DIR}

APP_VERSION="${CODEBUILD_RESOLVED_SOURCE_VERSION}-${CODEBUILD_BUILD_NUMBER}"

COMMIT=${CODEBUILD_RESOLVED_SOURCE_VERSION}
    
if [ ${ENVIRONMENT} = "production" ]; then
    APP_VERSION=$(echo ${CODEBUILD_WEBHOOK_TRIGGER} | sed -e 's#tag/##g' )

    if [ ${CODEBUILD_WEBHOOK_TRIGGER} = "" ]; then 
        APP_VERSION=$(git tag --sort=committerdate | tail -1)
        git checkout tags/${APP_VERSION}
        COMMIT=$(git rev-parse HEAD)
    fi
fi

if [ ${ENVIRONMENT} = "production" ]; then
    LOCATION="PRODUCTION"
    SLACK_URL=${PRODUCTION_NOTIFICATION_CHANNEL_URL}
else
    LOCATION="STAGING"
    SLACK_URL=${STAGING_NOTIFICATION_CHANNEL_URL}
fi

PIPELINE_NAME=$(echo ${CODEBUILD_BUILD_ID} | grep -o ".*:" | sed -r 's#:##g')

JOB_ID=$(echo ${CODEBUILD_BUILD_ID} | grep -o ":.*" | sed -r 's#:##g')

curl --request POST --url ${SLACK_URL} --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text": "Deployment of *'${SERVICE_REPO_NAME}'* on *'${LOCATION}'* environment has started: :loading-indicator:"}},{"type": "section","fields": [{"type":"mrkdwn","text": "*Repository:*\n'${CODEBUILD_SOURCE_REPO_URL}'"},{"type": "mrkdwn","text": "*Stage:*\n'${LOCATION}'"},{"type": "mrkdwn","text": "*Commit:*\n'${COMMIT}'"},{"type": "mrkdwn","text": "*App Version:*\n'${APP_VERSION}'"},{"type": "mrkdwn","text": "*Build Url:*\n<https://'${AWS_REGION}'.console.aws.amazon.com/codesuite/codebuild/'${ACCOUNT_ID}'/projects/'${PIPELINE_NAME}'/build/'${PIPELINE_NAME}'%3A'${JOB_ID}'/?region='${AWS_REGION}'|Click To View>"},{"type": "mrkdwn","text": "*Build Number:*\n'${CODEBUILD_BUILD_NUMBER}'"}]}]}'

HELM_S3_BUCKET_NAME="lendis-helm-${ENVIRONMENT}-repository"

ECR_BASE_URL=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

setup() {
    cd ${CODEBUILD_SRC_DIR} && cd ../

    wget https://releases.hashicorp.com/terraform/0.13.5/terraform_0.13.5_linux_amd64.zip
    unzip terraform_0.13.5_linux_amd64.zip
    cp ./terraform /usr/bin/

    curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

    wget https://github.com/mikefarah/yq/releases/download/v4.25.2/yq_linux_amd64
    chmod +x yq_linux_amd64
    cp ./yq_linux_amd64 /usr/bin/yq
    yq --version
}

build_application() {
    cd ${CODEBUILD_SRC_DIR}
    echo ${DOCKERHUB_PASSWORD} | docker login --username ${DOCKERHUB_USERNAME} --password-stdin
    docker build -t ${ECR_REPO_NAME} . --build-arg NPM_GH_TOKEN=${GH_TOKEN} --build-arg NODE_ENV=${ENVIRONMENT}
    aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_BASE_URL}
    docker tag ${ECR_REPO_NAME}:latest ${ECR_BASE_URL}/${ECR_REPO_NAME}:${APP_VERSION}
    docker push ${ECR_BASE_URL}/${ECR_REPO_NAME}:${APP_VERSION}
}

package_and_upload_helm_chart() {
    cd ${CODEBUILD_SRC_DIR} && cd ../ && cd ./${SERVICE_INFRA_FOLDER_NAME}
    CHART_VERSION=$(grep 'version: ' ./helm/Chart.yaml | sed -e 's#version: ##g')
    export CHART_VERSION=${CHART_VERSION}
    sed -i -e 's#appVersion: "1.0.0"#appVersion: "'${APP_VERSION}'"#g' ./helm/Chart.yaml
    rm -rf ./helm/Chart.yaml-e
    mkdir -p ./repository
    aws s3 cp s3://${HELM_S3_BUCKET_NAME}/${SERVICE_REPO_NAME}/ ./repository --recursive
    helm package --destination ./repository ./helm
    if [ -f ./repository/index.yaml ]; then
        helm repo index ./repository --merge ./repo/index.yamls
    else
        helm repo index ./repository
    fi
    aws s3 cp ./repository s3://${HELM_S3_BUCKET_NAME}/${SERVICE_REPO_NAME}/ --recursive
}

deploy_helm_chart(){
    cd ${CODEBUILD_SRC_DIR} && cd ../

    echo ${EKS_CONFIG_CONTEXT} |  yq eval -P  > ./eks.kubeconfig

    SECRET_ID="${SERVICE_REPO_NAME}-${ENVIRONMENT}-envs"
    
    aws secretsmanager get-secret-value --secret-id ${SECRET_ID} --region ${AWS_REGION} --query SecretString --output text > .env.json

    sed -i -e 's#{#{"envs":{#g' ./.env.json

    sed -i -e 's#}#}}#g' ./.env.json

    cat ./.env.json |  yq eval -P > ./override-values.yaml

    echo '{"image":{"tag":"'${APP_VERSION}'","repository":"'${ECR_BASE_URL}'/'${ECR_REPO_NAME}'"},"stage":"'${ENVIRONMENT}'","account":"'${ACCOUNT_ID}'"}' |  yq eval -P >> ./override-values.yaml

    sed -i -e "s#'#\"#g" ./override-values.yaml

    cat ./override-values.yaml

    helm repo add ${SERVICE_REPO_NAME} "https://${HELM_S3_BUCKET_NAME}.s3.amazonaws.com/${SERVICE_REPO_NAME}"

    helm upgrade --install "${SERVICE_REPO_NAME}-${ENVIRONMENT}" ${SERVICE_REPO_NAME}/${SERVICE_REPO_NAME}  --values ./override-values.yaml --kubeconfig ./eks.kubeconfig
}

create_service_account() {
    cd ${CODEBUILD_SRC_DIR} && cd ../ && cd ./${SERVICE_INFRA_FOLDER_NAME}/terraform
    terraform init -backend-config="${ENVIRONMENT}.hcl" -backend=true
    terraform apply -var="aws_region=${AWS_REGION}" -var="environment=${ENVIRONMENT}" -var="eks_cluster_name=${EKS_CLUSTER_NAME}" -var="service_account_name=${SERVICE_REPO_NAME}-${ENVIRONMENT}" -var="service_account_namespace=default" -auto-approve
}

setup
build_application
create_service_account
package_and_upload_helm_chart
deploy_helm_chart

curl --request POST --url ${SLACK_URL} --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text": "Deployment of *'${SERVICE_REPO_NAME}'* on *'${LOCATION}'* environment has finished successfully: :white_check_mark:"}},{"type": "section","fields": [{"type":"mrkdwn","text": "*Repository:*\n'${CODEBUILD_SOURCE_REPO_URL}'"},{"type": "mrkdwn","text": "*Stage:*\n'${LOCATION}'"},{"type": "mrkdwn","text": "*Commit:*\n'${COMMIT}'"},{"type": "mrkdwn","text": "*App Version:*\n'${APP_VERSION}'"},{"type": "mrkdwn","text": "*Build Url:*\n<https://'${AWS_REGION}'.console.aws.amazon.com/codesuite/codebuild/'${ACCOUNT_ID}'/projects/'${PIPELINE_NAME}'/build/'${PIPELINE_NAME}'%3A'${JOB_ID}'/?region='${AWS_REGION}'|Click To View>"},{"type": "mrkdwn","text": "*Build Number:*\n'${CODEBUILD_BUILD_NUMBER}'"}]}]}'