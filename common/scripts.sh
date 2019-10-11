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
  if [[ "$3" == "-h" ]] || [[ "$3" == "--help" ]] || [[ "$2" == "1" && "$#" -lt 3 ]]; then
    echo "$1"
    return 1
  fi
}

# Recursively clean all python cache files from current dir
# @see https://stackoverflow.com/a/41386937
pyclean () {
    find . -type f -name '*.py[co]' -delete -o -type d -name __pycache__ -delete
}



# In-depth info about deleting branches: https://stackoverflow.com/questions/2003505/how-do-i-delete-a-git-branch-locally-and-remotely
git_merged() {
  _show_help "$(cat <<-HELP
Show or remove merged branches, either local or remote, from the repository the local dir is in.

Usage:
  git_merged show|delete local|remote|all

  git_merged show all
  
  # nothing unusual there?
  # (Or, if you have other intends, run the output of the above command through xargs...)

  git_merged delete all
HELP
  )" 1 "$@" || return 0
  set -e

  # Script constants
  BRANCH_WHITELIST="(\*|master|develop)"
  REMOTES="origin"  # Add more remotes here as space-separated list

  # local
  if [[ $2 == "local" || $2 == "all" ]]; then
    for branch in $(git branch --merged master | egrep -v "$BRANCH_WHITELIST"); do
      if [[ $1 == "show" ]]; then echo "${branch}"; fi
      if [[ $1 == "delete" ]]; then git branch -d "${branch}"; fi
    done
  fi

  # remotes
  if [[ $2 == "remote" || $2 == "all" ]]; then
    for remote in "$REMOTES"; do
      git fetch "$remote" --prune
      for branch in $(git branch -r --merged master | grep "$remote" | egrep -v "$BRANCH_WHITELIST"); do
        if [[ $1 == "show" ]]; then echo "${branch}"; fi
        #  '#*/' part removes the preceding 'origin/' part from the branch name
        if [[ $1 == "delete" ]]; then git push "${remote}" --delete "${branch#*/}"; fi
      done
    done
  fi
}


set_workspace() {
  _show_help "$(cat <<-HELP
Consistently switch configuration of: AWS, Kubernetes, Kops 
     
Usage:
  set_workspace <aws-account> <role> <k8s-cluster (optional)> 

Assumes AWS profile names, Kubernetes context names and Kubernetes cluster name to follow consistent naming patterns.

Assumes Kubernetes contexts to be in separate configuration files (based on name), reducing risk of activating unexpected context.
The context searched for will be either <aws-account>-<role> (default clusters) or <k8s-cluster>.
HELP
  )" 1 "$@" || return 0

  ACCOUNT=$1
  ROLE=$2
  CLUSTER=$3

  # Determine AWS profile, Kube config file and context to use
  if [[ $ACCOUNT == reset ]]; then
    AWSPROF=default
    KUBE_CONFIG_FILE=default.config 
    KUBE_CONTEXT=minikube
  else
    AWSPROF=$ACCOUNT-$ROLE
    if [[ $CLUSTER ]]; then
      KUBE_CONFIG_FILE=$ACCOUNT/$CLUSTER.config 
      KUBE_CONTEXT=$CLUSTER
    else
      KUBE_CONFIG_FILE=$ACCOUNT/default.config
      KUBE_CONTEXT=$ACCOUNT-$ROLE
    fi
  fi

  # Configure AWS & Kubernetes
  export AWS_SDK_LOAD_CONFIG=1
  export AWS_PROFILE=${AWSPROF}
  KUBECONFIG=$HOME/.kube/${KUBE_CONFIG_FILE}
  export KUBECONFIG=$KUBECONFIG
  kubectl config use-context ${KUBE_CONTEXT}

  # Use correct KOPS version
  if [[ -f $HOME/.kube/$ACCOUNT/kops ]]; then
    # symlink found in account .kube folder
    export KOPS_BINARY=$HOME/.kube/$ACCOUNT/kops
  else
    export KOPS_BINARY='/usr/local/bin/kops-1.10.1'
  fi
}

# Using function over alias to allow expanding in bash scripts that use kops
kops() {
  $KOPS_BINARY "$@"
}
export -f kops
