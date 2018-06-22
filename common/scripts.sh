# Consistently switch configuration of: AWS, Kubernetes, Kops 
# 
# Usage:
#   set_workspace <name>
#
# Assumes AWS profile names, Kubernetes context names and Kops cluster name to follow consistent naming patterns.
# 
# Assumes Kubernetes contexts to be in separate configuration files, reducing risk of activating unexpected context.
set_workspace() {
  ACCOUNT=$1
  export KOPS_STATE_STORE=s3://${ACCOUNT}-kops-state
  export CLUSTER_NAME=${ACCOUNT}.k8s.cloud.sanoma.com
  export AWS_SDK_LOAD_CONFIG=1
  export AWS_PROFILE=${ACCOUNT}
  export KUBECONFIG=$HOME/.kube/${ACCOUNT}.config
  kubectl config use-context ${ACCOUNT}.k8s.cloud.sanoma.com
}