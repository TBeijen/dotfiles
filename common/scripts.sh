# Shows help message.
#  $1: The help message
#  $2: Whether to show the help message also on empty args list
#  $3...$n: Original functions arg list
#
# Call from shell function. Example:
# my_func()
#   _show_help "$(cat <<-HELP
#     the help
#     message
# HELP
# )" 1 "$@" || return 0
#   
#   # ... function code
# } 
_show_help() {
  if [[ "$3" == "-h" ]] || [[ "$2" == "1" && "$#" -lt 3 ]]; then
    echo "$1"
    return 1
  fi
}


set_workspace() {
  _show_help "$(cat <<-HELP
Consistently switch configuration of: AWS, Kubernetes, Kops 
     
Usage:
  set_workspace <name> <role>     

Assumes AWS profile names, Kubernetes context names and Kops cluster name to follow consistent naming patterns.

Assumes Kubernetes contexts to be in separate configuration files (based on name), reducing risk of activating unexpected context.
The context searched for will be <name>-<role>.
HELP
  )" 1 "$@" || return 0

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
  export KOPS_CLUSTER_NAME=${ACCOUNT}.k8s.cloud.sanoma.com
  # AWS
  export AWS_SDK_LOAD_CONFIG=1
  export AWS_PROFILE=${AWSPROF}

  # @TODO expand to symlink per account name to be able to differentiate test/prod kops versions
  alias kops='/usr/local/bin/kops-1.9.1'

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
