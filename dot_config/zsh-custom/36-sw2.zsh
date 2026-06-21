# sw2 — workspace+role activation prototype (Phase 5 design)
#
# Usage:
#   sw2 <client> <env> <role> [<cluster>]   activate workspace+role
#   sw2                                       leave workspace
#
# Workspace layout expected:
#   ~/workspaces/<client>/<env>/
#     mise.toml          # base — common workspace env (WS_CLIENT, WS_ENV)
#     mise.<role>.toml   # role overlay (WS_ROLE, AWS_PROFILE)
#     .kube/<cluster>    # cluster kubeconfig files
#
# Roles available per workspace = which mise.<role>.toml files exist.
#
# Mechanism: MISE_CONFIG_DIR points mise at the workspace dir.
# MISE_ENV selects the overlay. mise's auto-hook applies env vars
# on every prompt redraw and unsets them on leave. No manual eval needed.

sw2() {
  local WS_ROOT=${WORKSPACES_ROOT:-"$HOME/workspaces"}

  # Leave workspace
  if [[ $# -eq 0 ]]; then
    unset MISE_CONFIG_DIR MISE_ENV KUBECONFIG WORKSPACES_ACTIVE_ENV
    return 0
  fi

  if [[ $# -lt 3 ]]; then
    echo "Usage: sw2 <client> <env> <role> [<cluster>]"
    echo "       sw2                                     (leave workspace)"
    return 1
  fi

  local client="$1" env="$2" role="$3" cluster="$4"
  local ws="${WS_ROOT}/${client}/${env}"

  [[ -d "$ws" ]] || { echo "ERROR: workspace not found: $ws"; return 1; }
  [[ -f "$ws/mise.toml" ]] || { echo "ERROR: no mise.toml in $ws"; return 1; }

  if [[ ! -f "$ws/mise.${role}.toml" ]]; then
    local available=$(ls "$ws"/mise.*.toml 2>/dev/null \
      | sed "s|.*/mise\.\(.*\)\.toml|\1|" \
      | grep -v "^toml$" \
      | tr '\n' ' ')
    echo "ERROR: role '$role' not defined for ${client}/${env}"
    echo "Available roles: ${available:-none}"
    return 1
  fi

  # Activate via mise's natural mechanism
  export MISE_CONFIG_DIR="$ws"
  export MISE_ENV="$role"

  # Optional cluster
  if [[ -n "$cluster" ]]; then
    local kc="${ws}/.kube/${cluster}"
    [[ -r "$kc" ]] || { echo "ERROR: cluster file not found: $kc"; return 1; }
    export KUBECONFIG="$kc"
  else
    unset KUBECONFIG
  fi

  export WORKSPACES_ACTIVE_ENV="${client}/${env}/${role}"
}
