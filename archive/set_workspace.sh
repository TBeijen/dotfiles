set_workspace() {
  _show_help "$(cat <<-HELP
Consistently switch configuration of: AWS, Kubernetes, Kops 
     
Usage:
  set_workspace <aws-account> <role> <k8s-cluster> 
  set_workspace reset

Assumes AWS profile names, Kubernetes context names and Kubernetes cluster name to follow consistent naming patterns.

Assumes Kubernetes contexts to be in separate configuration files (based on name), reducing risk of activating unexpected context.
The context searched for will be <aws-account>-<role>.
HELP
  )" 1 "$@" || return 0

  ACCOUNT=$1
  ROLE=$2
  CLUSTER=$3

  # Determine AWS profile, Kube config file and context to use
  if [[ $ACCOUNT == reset ]]; then
    AWSPROF=default
    KUBE_CONFIG_FILE=$HOME/.kube/default.config 
    KUBE_CONTEXT=minikube

    export AWS_SDK_LOAD_CONFIG=1
    export KUBECONFIG=$KUBE_CONFIG_FILE
    unset AWS_PROFILE    
    # Not setting kube context. Leaving that to whatever is in default.config
  else
    AWSPROF=$ACCOUNT-$ROLE
    KUBE_CONFIG_FILE=$HOME/.kube/$ACCOUNT/$CLUSTER.config 
    KUBE_CONTEXT=$ACCOUNT-$CLUSTER

    # Configure AWS & Kubernetes
    export AWS_SDK_LOAD_CONFIG=1
    export AWS_PROFILE=${AWSPROF}
    export KUBECONFIG=$KUBE_CONFIG_FILE
    kubectl config use-context ${KUBE_CONTEXT}
  fi

  # Use correct KOPS version
  if [[ -f $HOME/.kube/$ACCOUNT/kops ]]; then
    # symlink found in account .kube folder
    export KOPS_BINARY=$HOME/.kube/$ACCOUNT/kops
  else
    export KOPS_BINARY='/usr/local/bin/kops-1.10.1'
  fi
}
sw() {
  set_workspace $@
}

# Using function over alias to allow expanding in bash scripts that use kops
kops() {
  $KOPS_BINARY "$@"
}
export -f kops
