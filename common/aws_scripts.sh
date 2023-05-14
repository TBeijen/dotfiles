# Login using MFA, acquiring neccessary permisisons
#
# Usage: aws_login <Google_Authenticator_Code>
aws_login() {
  MFA_ARN=$(aws --profile ${AWS_PROFILE:-default} --output text iam list-mfa-devices --query 'MFADevices[].SerialNumber')
  TOKEN_CODE=$1
  CREDENTIALS=$(aws --output json --profile ${AWS_PROFILE:-default} sts get-session-token --serial-number $MFA_ARN --token-code $TOKEN_CODE | jq -r '.Credentials')
  export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.AccessKeyId')
  export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.SecretAccessKey')
  export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.SessionToken')
}

# Lookup EC2 instance ip.
#
# Usage: 
#   aws_ip <Instance_Id>
#   ssh $(aws_ip <Instance_Id>)
aws_ip() {
  INSTANCE_ID=$1
  aws --output text ec2 describe-instances --instance-id $INSTANCE_ID --query 'Reservations[].Instances[].PrivateIpAddress'
}

# List auto scaling groups
#
# Usage:
#   aws_asg_list
aws_asg_list() {
  aws autoscaling describe-auto-scaling-groups | jq -r .AutoScalingGroups[].AutoScalingGroupName
}

# List instances of auto scaling group.
# Optionally sets desired capacity.
#
# Usage: 
#   aws_asg_instances <ASG_Name>
#   aws_asg_instances <ASG_Name> <Number_Of_Instances>
aws_asg_instances() {
  ASG_NAME=$1
  DESIRED_CAPACITY=$2
  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[].Instances[]'
  if [[ -n $DESIRED_CAPACITY ]]; then
    aws autoscaling set-desired-capacity --auto-scaling-group-name $ASG_NAME --desired-capacity $DESIRED_CAPACITY && \
    echo "Changed desired capacity to $DESIRED_CAPACITY"
  fi
}

# Add instance to autoscaling group. Increases desired capacity.
#
# Usage:
#   aws_asg_add <ASG_Name>
aws_asg_add() {
  ASG_NAME=$1
  CURRENT_CAPACITY=$(aws --output text autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[].DesiredCapacity')
  DESIRED_CAPACITY=$((CURRENT_CAPACITY+1))
  aws autoscaling set-desired-capacity --auto-scaling-group-name $ASG_NAME --desired-capacity $DESIRED_CAPACITY && \
    echo "Changed desired capacity to $DESIRED_CAPACITY"
}

# Show auto scaling group health
#
# Usage:
#   aws_asg_health <ASG_Name>
aws_asg_health() {
  ASG_NAME=$1
  aws elbv2 describe-target-health --target-group-arn $(aws --output text autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[].TargetGroupARNs[]') --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]'
}

# Replace instance in autoscaling group. Preserves desired capacity.
#
# Usage:
#   aws_asg_replace <Instance_Id>
aws_asg_replace() {
  INSTANCE_ID=$1
  aws autoscaling terminate-instance-in-auto-scaling-group --instance-id $INSTANCE_ID --no-should-decrement-desired-capacity
}

# Terminate instance in autoscaling group. Decreases desired capacity.
#
# Usage:
#   aws_asg_terminate <Instance_Id>
aws_asg_terminate() {
  INSTANCE_ID=$1
  aws autoscaling terminate-instance-in-auto-scaling-group --instance-id $INSTANCE_ID --should-decrement-desired-capacity
}


aws_s3_bucket_size() {
  _show_help "$(cat <<-HELP
Display bucket size and object count using Cloudwatch.

Usage:
  aws_s3_bucket_size <bucket-name>
HELP
)" 1 "$@" || return 0 

  # See: https://serverfault.com/questions/84815/how-can-i-get-the-size-of-an-amazon-s3-bucket
  BUCKET=$1
  NOW=$(date +%s)
  AVG_SIZE=172800

  bytes=$(aws cloudwatch get-metric-statistics --namespace AWS/S3 --start-time "$(echo "$now - $AVG_SIZE" | bc)" --end-time "$now" --period $AVG_SIZE --statistics Average --metric-name BucketSizeBytes --dimensions Name=BucketName,Value="$BUCKET" Name=StorageType,Value=StandardStorage |jq -r .Datapoints[0].Average)
  items=$(aws cloudwatch get-metric-statistics --namespace AWS/S3 --start-time "$(echo "$NOW - $AVG_SIZE" | bc)" --end-time "$NOW" --period $AVG_SIZE --statistics Average --metric-name NumberOfObjects --dimensions Name=BucketName,Value="$BUCKET" Name=StorageType,Value=AllStorageTypes |jq -r .Datapoints[0].Average)

  echo "Size (Gb): $(echo "scale=2; $bytes / 1024^3" | bc)"
  echo "Number of objects: $items"
}


aws_ecr_login() {
  _show_help "$(cat <<-HELP
    Login into ECR using the currently active AWS profile.
HELP
)" 0 "$@" || return 0
  REGION=$(aws configure get region)
  ACCOUNT=$(aws sts get-caller-identity | jq -r .Account)
  ECR_REPOSITORY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

  if command -v podman &> /dev/null
  then
      DOCKER_BINARY=podman
      # Sync Podman VM datetime, see: https://github.com/containers/podman/issues/11541#issuecomment-1176464030
      podman machine ssh sudo date --set $(date +'%Y-%m-%dT%H:%M:%S')
  else
      DOCKER_BINARY=docker
  fi

  echo "Logging in into ${ECR_REPOSITORY} (using ${DOCKER_BINARY})"
  aws ecr get-login-password | ${DOCKER_BINARY} login --password-stdin --username AWS ${ECR_REPOSITORY}
} 

aws_ec2_find() {
  _show_help "$(cat <<-HELP
Find ec2 instance id by its private dns/host name or private ip address.

Returns the i-nnnnnnn instance id, which can be used directly in ssh when having configured https://github.com/qoomon/aws-ssm-ec2-proxy-command

Usage:
  aws_ec2_find ip-10-11-12-13.eu-west-1.compute.internal
  ssh \$(aws_ec2_find ip-10-11-12-13.eu-west-1.compute.internal)
HELP
)" 1 "$@" || return 0
  SEARCH=$1

  # --filter using OR seems tricky, first attempt: by dns name
  INSTANCE_IDS=$(aws ec2 describe-instances --output=json --filter Name=private-dns-name,Values="${SEARCH}" |jq -r '.Reservations[].Instances[].InstanceId')
  if [ $(echo $INSTANCE_IDS |wc -w) -ne "1" ]; then
    # Second attempt: by private ip
    INSTANCE_IDS=$(aws ec2 describe-instances --output=json --filter Name=private-ip-address,Values="${SEARCH}" |jq -r '.Reservations[].Instances[].InstanceId')
  fi

  # Evaluate, print or return 1
  if [ $(echo $INSTANCE_IDS |wc -w) -eq "1" ]; then
    echo $INSTANCE_IDS
  else
    return 1
  fi
}

aws_sso_to_iam() {
  _show_help "$(cat <<-HELP
    Use cached SSO credentials to obtain AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN for the currently active profile. Returns json wrapped in 'roleCredentials'.
HELP
)" 0 "$@" || return 0
  token=$(find ~/.aws/sso/cache -type f -name '*.json' -exec jq -r -e 'select(has("accessToken") and (.expiresAt | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) > now) | .accessToken' {} \; |head -n1)

  if [ -z "$token" ]; then
    echo "No SSO access token found. Probably the session has expired. Log in using:\n\naws sso login"
    return 1
  fi

  if [ -z "$AWS_PROFILE" ]; then
    echo "Be sure to activate a profile"
    return 1
  fi

  section=$(sed -n '/^\[profile '"$AWS_PROFILE"'\]/,/^$/p' ~/.aws/config)

  aws_account_id=$(echo "$section" | awk -F ' = ' '/^sso_account_id/{print $2}')
  sso_role_name=$(echo "$section" | awk -F ' = ' '/^sso_role_name/{print $2}')
  region=$(echo "$section" | awk -F ' = ' '/^region/{print $2}')

  LESS="-FXR" aws sso get-role-credentials --account-id $aws_account_id --role-name $sso_role_name --access-token "$token" --region $region
}



# Set AWS profile
# 
# Usage:
#   aws_set_profile <Config_Profile>
#   aws_set_profile sandbox
aws_set_profile() {
  VALID_PROFILES=($(grep -E "^\[.+\]$" ~/.aws/config | sed -e 's!\[!!g' -e 's!profile !!g' -e 's!\]!!g'))
  for ((i = 0; i < ${#VALID_PROFILES[@]}; i++)); do
    if [[ ${VALID_PROFILES[$i]} = $1 ]]; then
        break
    fi
  done
  if ((i == ${#VALID_PROFILES[@]})); then
    echo -e "${red}Unknown profile, abort${reset}"
  else
    export AWS_PROFILE=$1
  fi
}

# List available AWS profiles
# 
# Usage:
#   aws_get_profiles
aws_get_profiles() {
    grep -E "^\[.+\]$" ~/.aws/config | sed -e 's!\[!!g' -e 's!profile !!g' -e 's!\]!!g'
}

aws_mfa() {
  # Loosely based on https://github.com/sweharris/aws-cli-mfa/blob/master/get-aws-creds
  # @TODO better integrate with profile assume_role config. Now it's probably possible to switch workspace having mismatch between prompt and env vars set by this script
  # @TODO simplify, maybe use jq like elsewhere
  _show_help "$(cat <<-HELP
Get session credentials using registered MFA device.
Will clear any existing session env vars.

Usage:
  aws_mfa <mfa-code>
  aws_mfa 123654
HELP
)" 1 "$@" || return 0
  CODE=$1

  if [ -n "$AWS_SESSION_TOKEN" ]
  then
    echo "Clearing exsting session credentials."
    unset AWS_SESSION_TOKEN AWS_SECRET_ACCESS_KEY AWS_ACCESS_KEY_ID
  fi

  identity=$(aws sts get-caller-identity)
  username=$(echo -- "$identity" | sed -n 's!.*"arn:aws:iam::.*:user/\(.*\)".*!\1!p')
  if [ -z "$username" ]
  then
    echo "Can not identify who you are.  Looking for a line like 'arn:aws:iam::.....:user/FOO_BAR' but did not find one in the output of
    aws sts get-caller-identity
      $identity" >&2
    exit 255
  fi

  echo You are: $username >&2

  mfa=$(aws iam list-mfa-devices --user-name "$username")
  device=$(echo -- "$mfa" | sed -n 's!.*"SerialNumber": "\(.*\)".*!\1!p')
  if [ -z "$device" ]
  then
    echo "Can not find any MFA device for you. Looking for a SerialNumber but did not find one in the output of
    aws iam list-mfa-devices --username \"$username\"
      $mfa" >&2
    exit 255
  fi

  echo Your MFA device is: $device >&2

  tokens=$(aws sts get-session-token --serial-number "$device" --token-code $CODE)

  secret=$(echo -- "$tokens" | sed -n 's!.*"SecretAccessKey": "\(.*\)".*!\1!p')
  session=$(echo -- "$tokens" | sed -n 's!.*"SessionToken": "\(.*\)".*!\1!p')
  access=$(echo -- "$tokens" | sed -n 's!.*"AccessKeyId": "\(.*\)".*!\1!p')
  expire=$(echo -- "$tokens" | sed -n 's!.*"Expiration": "\(.*\)".*!\1!p')

  if [ -z "$secret" -o -z "$session" -o -z "$access" ]
  then
    echo "Unable to get temporary credentials.  Could not find secret/access/session entries
      $tokens" >&2
    exit 255
  fi

  export AWS_PROFILE=$AWS_PROFILE
  export AWS_SESSION_TOKEN=$session
  export AWS_SECRET_ACCESS_KEY=$secret
  export AWS_ACCESS_KEY_ID=$access

  echo Keys valid until $expire >&2




}

complete -W "$(aws_get_profiles)" aws_set_profile
