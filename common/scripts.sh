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

  # @TODO define binary per per account name to be able to differentiate test/prod kops versions
  export KOPS_BINARY='/usr/local/bin/kops-1.10.1'

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

# Using function over alias to allow expanding in bash scripts that use kops
kops() {
  $KOPS_BINARY "$@"
}
export -f kops
