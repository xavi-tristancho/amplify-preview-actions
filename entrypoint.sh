#!/bin/sh

set -e

BRANCH_NAME=$1
AMPLIFY_COMMAND=$2
COMMENT_URL=$3

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] ; then
  echo "You must provide the action with both AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables in order to deploy"
  exit 1
fi

if [ -z "$AWS_REGION" ] ; then
  AWS_REGION="us-east-1"
fi

if [ -z "$AmplifyAppId" ] ; then
  echo "You must provide AmplifyAppId environment variable in order to deploy"
  exit 1
fi

if [ -z "$BRANCH_NAME" ] ; then
  echo "You must provide branch name input parameter in order to deploy"
  exit 1
fi

if [ -z "$AMPLIFY_COMMAND" ] ; then
  echo "You must provide amplify_command input parameter in order to deploy"
  exit 1
fi

aws configure --profile amplify-preview-actions <<-EOF > /dev/null 2>&1
${AWS_ACCESS_KEY_ID}
${AWS_SECRET_ACCESS_KEY}
${AWS_REGION}
text
EOF

echo "Trying to deploy"

case $AMPLIFY_COMMAND in

  deploy)
    echo "Check if branch is new"
    is_new_branch=true
    if sh -c "aws amplify get-branch --app-id=${AmplifyAppId} --branch-name=$BRANCH_NAME --region=${AWS_REGION}"; then
      is_new_branch=false
    else
      is_new_branch=true
    fi

    echo "Is branch new: $is_new_branch"

    if [ "$is_new_branch" = true ] ; then
      sh -c "aws amplify create-branch --app-id=${AmplifyAppId} --branch-name=$BRANCH_NAME --region=${AWS_REGION}"
      sleep 10
    fi

    output=$(sh -c "aws amplify start-job --app-id=${AmplifyAppId} --branch-name=$BRANCH_NAME --job-type=RELEASE --region=${AWS_REGION}")
    job_id=$(echo $output | sed -n 's/^.*"jobId": "\([0-9].\)",.*$/\1/p')    

    while : ; do
        echo "Checking if job is completed"
        if sh -c "aws amplify get-job --app-id=${AmplifyAppId} --branch-name=$BRANCH_NAME --job-id=${job_id} --region=${AWS_REGION} | grep -oE '\"endTime\":.*\"'"; then
          echo "Job is completed"
          break;
        else
          echo "Job is not completed"
          sleep 20
        fi          
    done
    ;;

  delete)
    sh -c "aws amplify delete-branch --app-id=${AmplifyAppId} --branch-name=$BRANCH_NAME --region=${AWS_REGION}"
    ;;

  *)
    echo "amplify command $AMPLIFY_COMMAND is invalid or not supported"
    exit 1
    ;;

esac