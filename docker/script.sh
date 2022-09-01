#!/bin/bash

export AWS_ACCESS_KEY_ID=${1}
export AWS_SECRET_ACCESS_KEY=${2}
export AWS_SESSION_TOKEN=${3}
export AWS_REGION=${4} 
export SERVICE_NAME=${5}
export STAGE=${6}

upload_file() {
    FILE=${1}

    echo ${FILE}

    RELATIVE_PATH=$(echo ${FILE} | sed -r 's#/app/##g')

    aws s3 mv "${FILE}" "s3://lendis-eks-source-maps/${SERVICE_NAME}/${STAGE}/${RELATIVE_PATH}" --region ${AWS_REGION}
}

export -f upload_file

find /app -type f -name '*.js.map' -not -path "/app/node_modules/*" -exec bash -c "upload_file \"{}\"" \;