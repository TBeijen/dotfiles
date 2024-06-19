# Wrapper around autoenv (not overriding cd)
# Leverages the autoenv package to 'set_workspace', resulting in .envrc of a particular workspace to be loaded
# (and unloaded if .envrc.leave is in place)
#
# Additonally a specific k8s cluster can be provided, resulting in only that kubeconfig being active 
# (no cross-terminal accidental cluster switching)
#
# Examples:
#   sw personal d (soures ~/workspaces/personal/d/.envrc)
#   sw client_a test cluster1 (sources ~/workspaces/client_a/test/.envrc, sets KUBE_CONFIG to ~/workspaces/client_a/test/.kube/cluster1.conf)
sw() {
  local WS_ROOT=${WORKSPACES_ROOT:-"$HOME/workspaces"}
  local WS_KUBE WS_RESET
  case $# in
    0)
      local WS_RESET=True
      ;;
    2)
      local WS_PROJ=${1}
      local WS_ENV=${2}
      ;;
    3)
      local WS_PROJ=${1}
      local WS_ENV=${2}
      local WS_KUBE=${3}
      ;;
    *)
      echo "USAGE: $0 <project> <environment> [<k8s_cluster>]"
      return 1
      ;;
  esac

  # Args evaluated, we always leave any current active workspace
  # Execute autoenv leave ourselves not as part of init, since we want it to run from the active workspace, not the current dir
  if [[ -n "$AUTOENV_ENABLE_LEAVE" ]] && [[ ! -z ${WORKSPACES_ACTIVE_ENV} ]]; then
    autoenv_leave "${WORKSPACES_ACTIVE_ENV}"
  fi

  # Reset if no args
  if [[ ! -z ${WS_RESET} ]];then
    unset KUBECONFIG
    return 0
  fi

  # Construct and validate workspace env path
  local WS_PATH=${WS_ROOT}/${WS_PROJ}/${WS_ENV}
  if [[ ! -d ${WS_PATH} ]]; then
    echo "ERROR: Directory ${WS_PATH} not found"
    return 1
  fi

  # Execute autoenv_init, disabling leave since we already handled that ourselves
  PWD=${WS_PATH} WORKSPACES_ROOT=${WS_ROOT} AUTOENV_ENABLE_LEAVE="" autoenv_init
  
  # Export workspace that is now active
  export WORKSPACES_ACTIVE_ENV=${WS_PATH}

  # Optionally specify kube config
  if [[ ! -z ${WS_KUBE} ]];then
    local WS_KUBE_CONFIG=${WS_PATH}/.kube/${WS_KUBE}
    if [[ ! -r ${WS_KUBE_CONFIG} ]]; then
      echo "ERROR: ${WS_KUBE_CONFIG} not found"
      return 1
    fi
    export KUBECONFIG=${WS_KUBE_CONFIG}
  else 
    unset KUBECONFIG
  fi
}