# ~/.bash_profile
# Make login shells and interactive non-login shells the same
if [ -f ~/.bashrc ]; then
   source ~/.bashrc
fi


awsLogin() {
  MFA_ARN=$(aws --profile ${AWS_PROFILE:-default} --output text iam list-mfa-devices --query 'MFADevices[].SerialNumber')
  TOKEN_CODE=$1
  CREDENTIALS=$(aws --output json --profile ${AWS_PROFILE:-default} sts get-session-token --serial-number $MFA_ARN --token-code $TOKEN_CODE | jq -r '.Credentials')
  export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.AccessKeyId')
  export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.SecretAccessKey')
  export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.SessionToken')
}
