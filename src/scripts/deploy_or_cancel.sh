#!/usr/bin/env bash

SetupEnv() {
  I_REGION=$(eval echo "${I_REGION}")
  I_SERVICE_NAME=$(eval echo "${I_SERVICE_NAME}")
  I_ACCOUNT_CANONICAL_SLUG=$(eval echo "${I_ACCOUNT_CANONICAL_SLUG}")
  I_DEPLOYOMAT_CANONICAL_SLUG=$(eval echo "${I_DEPLOYOMAT_CANONICAL_SLUG}")
  I_ROLE_EXTERNAL_ID=$(eval echo "${I_ROLE_EXTERNAL_ID}")
  I_AMI_ID=$(eval echo "${I_AMI_ID}")
  I_MANIFEST_PATH=$(eval echo "${I_MANIFEST_PATH}")
  I_DEPLOY_CONFIG_FILE=$(eval echo "${I_DEPLOY_CONFIG_FILE}")
  I_DEPLOYER_ROLE_PARAM_NAME=$(eval echo "${I_DEPLOYER_ROLE_PARAM_NAME}")
  I_DEPLOYOMAT_SERVICE_NAME=$(eval echo "${I_DEPLOYOMAT_SERVICE_NAME}")

  echo "I_REGION=$I_REGION"
  echo "I_SERVICE_NAME=$I_SERVICE_NAME"
  echo "I_ACCOUNT_CANONICAL_SLUG=$I_ACCOUNT_CANONICAL_SLUG"
  echo "I_DEPLOYOMAT_CANONICAL_SLUG=$I_DEPLOYOMAT_CANONICAL_SLUG"
  echo "I_ROLE_EXTERNAL_ID=$I_ROLE_EXTERNAL_ID"
  echo "I_AMI_ID=$I_AMI_ID"
  echo "I_MANIFEST_PATH=$I_MANIFEST_PATH"
  echo "I_DEPLOY_CONFIG_FILE=$I_DEPLOY_CONFIG_FILE"
  echo "I_ACTION=$I_ACTION"
  echo "I_DEPLOYER_ROLE_PARAM_NAME=${I_DEPLOYER_ROLE_PARAM_NAME}"
  echo "I_DEPLOYOMAT_SERVICE_NAME=${I_DEPLOYOMAT_SERVICE_NAME}"

  export AWS_REGION=$I_REGION
}

GetAmiId() {
  if [ -z "$I_AMI_ID" ]; then
    PARAM_PREFIX=$(aws ssm get-parameter --name "/omat/account_registry/${I_ACCOUNT_CANONICAL_SLUG}" --output text --query Parameter.Value | jq --raw-output '.prefix')
    ARCHITECTURE=$(aws ssm get-parameter --name "${PARAM_PREFIX}/config/${I_SERVICE_NAME}/architecture" --output text --query Parameter.Value)
    echo "ARCHITECTURE=$ARCHITECTURE"
    echo "Extracting AMI id from packer manifest..."
    I_AMI_ID=$(jq --arg arch "$ARCHITECTURE" -r '.builds | map(select(.custom_data.arch == $arch)) | map(select(.artifact_id | startswith($ENV.I_REGION))) | .[0].artifact_id | split(":") | .[1]' < "${I_MANIFEST_PATH}")
    echo "I_AMI_ID=$I_AMI_ID"
  fi
}

GetRoleAndSfnArn() {
  PARAM_PREFIX=$(aws ssm get-parameter --name "/omat/account_registry/${I_DEPLOYOMAT_CANONICAL_SLUG}" --output text --query Parameter.Value | jq --raw-output '.prefix')
  echo "PARAM_PREFIX=$PARAM_PREFIX"
  ROLE_ARN=$(aws ssm get-parameter --name "${PARAM_PREFIX}/roles/${I_DEPLOYER_ROLE_PARAM_NAME}" --output text --query Parameter.Value)
  SFN_ARN=$(aws ssm get-parameter --name "${PARAM_PREFIX}/config/${I_DEPLOYOMAT_SERVICE_NAME}/${I_ACTION}_sfn_arn" --output text --query Parameter.Value)
}

AssumeRole() {
  echo "Assuming role ${ROLE_ARN}"
  if [ -z "$I_ROLE_EXTERNAL_ID" ]; then
    eval "$(aws sts assume-role --role-arn "${ROLE_ARN}" --role-session-name "${I_SERVICE_NAME}" | jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)\n"')"
  else
    eval "$(aws sts assume-role --external-id "${I_ROLE_EXTERNAL_ID}" --role-arn "${ROLE_ARN}" --role-session-name "${I_SERVICE_NAME}" | jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)\n"')"
  fi
}

Execute() {
  echo "Executing state machine to ${I_ACTION} ${I_SERVICE_NAME} in ${I_ACCOUNT_CANONICAL_SLUG}"
  aws stepfunctions start-execution --state-machine-arn "$SFN_ARN" --input "$INPUT"
}

BuildInput() {
  INPUT=$(jq --null-input --arg acct "$I_ACCOUNT_CANONICAL_SLUG" --arg srv "$I_SERVICE_NAME" '{"AccountCanonicalSlug": $acct, "ServiceName": $srv}')
  if [ "$I_ACTION" = "deploy" ]; then
    INPUT=$(echo "$INPUT" | jq --arg ami "$I_AMI_ID" '.AmiId |= $ami')
    if [ -n "$I_DEPLOY_CONFIG_FILE" ]; then
      if [ ! -e "$I_DEPLOY_CONFIG_FILE" ]; then
        echo "Could not find configuration file ${I_DEPLOY_CONFIG_FILE}"
        exit 1
      fi

      INPUT=$(echo "$INPUT" | jq --slurpfile conf "$I_DEPLOY_CONFIG_FILE" '.DeployConfig |= $conf[0]')
    fi
  fi
}

SetupEnv
if [ "$I_ACTION" = "deploy" ]; then
  GetAmiId
fi
GetRoleAndSfnArn
BuildInput
AssumeRole
Execute
