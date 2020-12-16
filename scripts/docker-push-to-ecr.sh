#!/bin/bash

printUsage() {
  echo "Usage: $0 <buildId>"
  echo "    buildId: A unique string to use to identify the build"
}

if [ $# -eq 0 ]; then
    echo "Missing parameter: buildId"
    printUsage
    exit 1
fi

BUILD_ID=$1
APPLICATION_NAME=express
AWS_REGION=eu-west-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')

echo "BUILD_ID: ${BUILD_ID}"
echo "APPLICATION_NAME: ${APPLICATION_NAME}"
echo "AWS_ACCOUNT_ID: ${AWS_ACCOUNT_ID}"
echo "AWS_REGION: ${AWS_REGION}"

aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
docker tag "${APPLICATION_NAME}:${BUILD_ID}" "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APPLICATION_NAME}:${BUILD_ID}"
docker push "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APPLICATION_NAME}:${BUILD_ID}"
