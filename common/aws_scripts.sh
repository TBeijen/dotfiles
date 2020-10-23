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
  echo "Logging in into ${ECR_REPOSITORY}"
  aws ecr get-login-password | docker login --password-stdin --username AWS ${ECR_REPOSITORY}
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
complete -W "$(aws_get_profiles)" aws_set_profile
