# --- set_workspace (sw) + completions (zsh-native + bash) -----------------

# Only proceed for interactive shells
case $- in *i*) ;; *) return 0 2>/dev/null || exit 0 ;; esac

# ---------------- sw function ----------------
sw() {
  local WS_ROOT=${WORKSPACES_ROOT:-"$HOME/workspaces"}
  local WS_KUBE WS_RESET WS_PROJ WS_ENV
  case $# in
    0) WS_RESET=True ;;
    2) WS_PROJ=${1}; WS_ENV=${2} ;;
    3) WS_PROJ=${1}; WS_ENV=${2}; WS_KUBE=${3} ;;
    *) echo "USAGE: $0 <project> <environment> [<k8s_cluster>]"; return 1 ;;
  esac

  # Leave current workspace (do this from the active workspace)
  if [[ -n "$AUTOENV_ENABLE_LEAVE" && -n "${WORKSPACES_ACTIVE_ENV}" ]]; then
    autoenv_leave "${WORKSPACES_ACTIVE_ENV}"
  fi

  # Reset if no args
  if [[ -n ${WS_RESET} ]]; then
    unset KUBECONFIG
    return 0
  fi

  # Construct and validate path
  local WS_PATH=${WS_ROOT}/${WS_PROJ}/${WS_ENV}
  if [[ ! -d ${WS_PATH} ]]; then
    echo "ERROR: Directory ${WS_PATH} not found"
    return 1
  fi

  # Enter workspace (.envrc)
  PWD=${WS_PATH} WORKSPACES_ROOT=${WS_ROOT} AUTOENV_ENABLE_LEAVE="" autoenv_init
  export WORKSPACES_ACTIVE_ENV=${WS_PATH}

  # Optional kubeconfig (file within .kube)
  if [[ -n ${WS_KUBE} ]]; then
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

: "${WORKSPACES_ROOT:=$HOME/workspaces}"

# ---------------- Shared helpers ----------------
_sw_basename() {
  local p="$1"; p="${p%/}"; printf '%s\n' "${p##*/}"
}

_sw_list_child_dirs_one_level() {
  local root="$1" d name
  [[ -d "$root" ]] || return 0
  for d in "$root"/*(N); do
    name="$(_sw_basename "$d")"
    [[ "$name" == .* ]] && continue
    if [[ -d "$d" || ( -L "$d" && -d "${d:A}" ) ]]; then
      print -r -- "$name"
    fi
  done 2>/dev/null
}

_sw_resolved_kube_dir() {
  local proj="$1" env="$2" base="$WORKSPACES_ROOT/$proj/$env"
  [[ -d "$base" ]] || return 0
  (
    cd "$base" 2>/dev/null || exit 0
    [[ -d ".kube" ]] || exit 0
    cd -P ".kube" 2>/dev/null || exit 0
    pwd
  )
}

_sw_list_kube_files() {
  local kube_dir="$1" f name
  [[ -d "$kube_dir" ]] || return 0
  for f in "$kube_dir"/*(N); do
    name="$(_sw_basename "$f")"
    [[ "$name" == .* ]] && continue
    [[ -f "$f" ]] && print -r -- "$name"
  done 2>/dev/null
}

# ---------------- zsh-native completion ----------------
if [[ -n ${ZSH_VERSION-} ]]; then
  # Make sure completion system is initialized
  if ! whence -w compinit >/dev/null; then
    autoload -U +X compinit
  fi
  if ! typeset -f _sw >/dev/null; then
    _sw() {
      local -a suggestions
      local curcontext="$curcontext" state line
      _arguments -C \
        '1:project:->project' \
        '2:environment:->env' \
        '3:k8s_cluster:->cluster' && return

      case $state in
        project)
          suggestions=($(_sw_list_child_dirs_one_level "$WORKSPACES_ROOT"))
          _describe -t projects 'projects' suggestions && return
          ;;
        env)
          local proj=${words[2]}
          suggestions=($(_sw_list_child_dirs_one_level "$WORKSPACES_ROOT/$proj"))
          _describe -t environments 'environments' suggestions && return
          ;;
        cluster)
          local proj=${words[2]} env=${words[3]}
          local kube_dir="$(_sw_resolved_kube_dir "$proj" "$env")"
          suggestions=($(_sw_list_kube_files "$kube_dir"))
          _describe -t clusters 'k8s clusters' suggestions && return
          ;;
      esac
    }
  fi
  compdef _sw sw
fi

# ---------------- bash completion (if sourced under bash) ----------------
if [[ -n ${BASH_VERSION-} ]]; then
  _sw_complete_bash() {
    local cur words cword
    COMPREPLY=()
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
    cur="${COMP_WORDS[COMP_CWORD]}"

    if (( cword == 1 )); then
      COMPREPLY=( $(compgen -W "$(_sw_list_child_dirs_one_level "$WORKSPACES_ROOT")" -- "$cur") )
    elif (( cword == 2 )); then
      local proj="${words[1]}"
      COMPREPLY=( $(compgen -W "$(_sw_list_child_dirs_one_level "$WORKSPACES_ROOT/$proj")" -- "$cur") )
    elif (( cword == 3 )); then
      local proj="${words[1]}" env="${words[2]}"
      local kube_dir="$(_sw_resolved_kube_dir "$proj" "$env")"
      if [[ -n "$kube_dir" ]]; then
        COMPREPLY=( $(compgen -W "$(_sw_list_kube_files "$kube_dir")" -- "$cur") )
      fi
    fi
    return 0
  }
  type compopt >/dev/null 2>&1 && compopt -o nospace >/dev/null 2>&1
  complete -F _sw_complete_bash -o default -o bashdefault sw 2>/dev/null || true
fi
