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

curl --request POST --url ${SLACK_URL} --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text": "@channel Deployment of *'${SERVICE_REPO_NAME}'* on *'${LOCATION}'* environment has failed: :rotating_light:"}},{"type": "section","fields": [{"type":"mrkdwn","text": "*Repository:*\n'${CODEBUILD_SOURCE_REPO_URL}'"},{"type": "mrkdwn","text": "*Stage:*\n'${LOCATION}'"},{"type": "mrkdwn","text": "*Commit:*\n'${COMMIT}'"},{"type": "mrkdwn","text": "*App Version:*\n'${APP_VERSION}'"},{"type": "mrkdwn","text": "*Build Url:*\n<https://'${AWS_REGION}'.console.aws.amazon.com/codesuite/codebuild/'${ACCOUNT_ID}'/projects/'${PIPELINE_NAME}'/build/'${PIPELINE_NAME}'%3A'${JOB_ID}'/?region='${AWS_REGION}'|Click To View>"},{"type": "mrkdwn","text": "*Build Number:*\n'${CODEBUILD_BUILD_NUMBER}'"}]}]}'
exit 1