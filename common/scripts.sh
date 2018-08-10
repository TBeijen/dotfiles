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
  ROLE=$2
  CONTEXT=$ACCOUNT
  AWSPROF=$ACCOUNT
  if [[ $ROLE ]]; then
  	CONTEXT=$ACCOUNT-$ROLE
    AWSPROF=$ACCOUNT-$ROLE
  fi
  # Kops
  export KOPS_STATE_STORE=s3://${ACCOUNT}-kops-state
  export CLUSTER_NAME=${ACCOUNT}.k8s.cloud.sanoma.com
  # AWS
  export AWS_SDK_LOAD_CONFIG=1
  export AWS_PROFILE=${AWSPROF}
  # Kube
  KUBECONFIG=$HOME/.kube/${ACCOUNT}.config
  if [ -f $KUBECONFIG ]; then
    export KUBECONFIG=$KUBECONFIG
    kubectl config use-context ${CONTEXT}
  else
    # default = local minikube
    export KUBECONFIG=$HOME/.kube/default.config
    kubectl config use-context minikube
  fi
}