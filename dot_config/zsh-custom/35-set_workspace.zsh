# sw — workspace+role activation
#
# Usage:
#   sw <client> <env> <role> [<cluster>]   activate workspace+role
#   sw                                       leave workspace
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
# on every prompt redraw and unsets them on leave. We invoke
# `mise hook-env` synchronously to avoid a one-prompt-late redraw
# caused by oh-my-posh's precmd running before mise's precmd.

sw() {
  local WS_ROOT=${WORKSPACES_ROOT:-"$HOME/workspaces"}

  # Leave workspace
  if [[ $# -eq 0 ]]; then
    unset MISE_CONFIG_DIR MISE_ENV KUBECONFIG WORKSPACES_ACTIVE_ENV
    if command -v mise &>/dev/null; then
      eval "$(mise hook-env -s zsh 2>/dev/null)"
    fi
    return 0
  fi

  if [[ $# -lt 3 ]]; then
    echo "Usage: sw <client> <env> <role> [<cluster>]"
    echo "       sw                                     (leave workspace)"
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

  export MISE_CONFIG_DIR="$ws"
  export MISE_ENV="$role"

  if command -v mise &>/dev/null; then
    eval "$(mise hook-env -s zsh 2>/dev/null)"
  fi

  if [[ -n "$cluster" ]]; then
    local kc="${ws}/.kube/${cluster}"
    [[ -r "$kc" ]] || { echo "ERROR: cluster file not found: $kc"; return 1; }
    export KUBECONFIG="$kc"
  else
    unset KUBECONFIG
  fi

  export WORKSPACES_ACTIVE_ENV="${client}/${env}/${role}"
}

# ---------------- Tab completion (zsh-native) ----------------
# Only proceed for interactive shells
case $- in *i*) ;; *) return 0 2>/dev/null || exit 0 ;; esac

_sw_basename() {
  local p="$1"; p="${p%/}"; printf '%s\n' "${p##*/}"
}

# List immediate subdirs of $1. If must_have_mise=1, only include dirs containing mise.toml.
_sw_list_dirs() {
  local root="$1" must_have_mise="${2:-0}" d name
  [[ -d "$root" ]] || return 0
  for d in "$root"/*(N); do
    name="$(_sw_basename "$d")"
    [[ "$name" == .* ]] && continue
    [[ -d "$d" || ( -L "$d" && -d "${d:A}" ) ]] || continue
    if [[ "$must_have_mise" == "1" ]]; then
      [[ -f "$d/mise.toml" ]] || continue
    fi
    print -r -- "$name"
  done 2>/dev/null
}

_sw_list_roles() {
  local ws="$1" f name role
  [[ -d "$ws" ]] || return 0
  for f in "$ws"/mise.*.toml(N); do
    name="$(_sw_basename "$f")"
    role="${name#mise.}"
    role="${role%.toml}"
    [[ "$role" == "toml" ]] && continue
    print -r -- "$role"
  done 2>/dev/null
}

_sw_list_clusters() {
  local kube_dir="${1}/.kube" f name
  [[ -d "$kube_dir" ]] || return 0
  for f in "$kube_dir"/*(N); do
    name="$(_sw_basename "$f")"
    [[ "$name" == .* ]] && continue
    [[ -f "$f" ]] && print -r -- "$name"
  done 2>/dev/null
}

if [[ -n ${ZSH_VERSION-} ]]; then
  if ! whence -w compinit >/dev/null; then
    autoload -U +X compinit
  fi
  if ! typeset -f _sw >/dev/null; then
    _sw() {
      local -a suggestions
      local curcontext="$curcontext" state line
      local WS_ROOT=${WORKSPACES_ROOT:-"$HOME/workspaces"}

      _arguments -C \
        '1:client:->client' \
        '2:env:->env' \
        '3:role:->role' \
        '4:cluster:->cluster' && return

      case $state in
        client)
          suggestions=($(_sw_list_dirs "$WS_ROOT"))
          _describe -t clients 'clients' suggestions && return
          ;;
        env)
          local client=${words[2]}
          suggestions=($(_sw_list_dirs "$WS_ROOT/$client" 1))
          _describe -t envs 'envs' suggestions && return
          ;;
        role)
          local client=${words[2]} env=${words[3]}
          suggestions=($(_sw_list_roles "$WS_ROOT/$client/$env"))
          _describe -t roles 'roles' suggestions && return
          ;;
        cluster)
          local client=${words[2]} env=${words[3]}
          suggestions=($(_sw_list_clusters "$WS_ROOT/$client/$env"))
          _describe -t clusters 'clusters' suggestions && return
          ;;
      esac
    }
  fi
  compdef _sw sw
fi
