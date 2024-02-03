# Resources:
# https://dev.to/yujinyuz/custom-colors-in-oh-my-zsh-themes-4h13
# https://scriptingosx.com/2019/07/moving-to-zsh-06-customizing-the-zsh-prompt/
# https://www.ditig.com/256-colors-cheat-sheet
# https://zsh.sourceforge.io/Doc/Release/Prompt-Expansion.html#Prompt-Expansion

function __status() { 
    if [ $? -eq 0 ]; then 
        echo -en "%{$fg[green]%}✔%{$reset_color%} " 
    else 
        echo -en "%{$fg[red]%}✘%{$reset_color%} "
    fi 
} 

function __awsprofile() {
  local promptColor="%F{208}"
  if [ -z $AWS_PROFILE ]; then
      local prompt="${promptColor}[default]%{$reset_color%}%f "
  else
      local prompt="${promptColor}[$AWS_PROFILE]%{$reset_color%}%f "
  fi

  local prompt=$(echo $prompt |sed "s/prod/%B%F{196}PROD%b%f${promptColor}/")

  # WS_PROFILE_SAFE_SUFFIX is set, color that green
  if [ ! -z $WS_PROFILE_UNSAFE_MARKER ]; then
    local prompt=$(echo $prompt |sed "s/${WS_PROFILE_UNSAFE_MARKER}/%B%F{196}${WS_PROFILE_UNSAFE_MARKER}%b%f${promptColor}/")
  fi

  # WS_PROFILE_SAFE_MARKER is set, color that green
  if [ ! -z $WS_PROFILE_SAFE_MARKER ]; then
    local prompt=$(echo $prompt |sed "s/${WS_PROFILE_SAFE_MARKER}/%{$fg[green]%}${WS_PROFILE_SAFE_MARKER}%{$reset_color%}${promptColor}/")
  fi
  echo -en "${prompt}"
}

function __azinfo() {
  local promptColor="%F{39}"
  azgs=$(jq -r '.subscriptions[] | select(.isDefault==true) .name' "${AZURE_CONFIG_DIR:-$HOME/.azure}/azureProfile.json" 2>/dev/null)
  if [ -z $azgs ]; then
      local prompt=""
  else
      local prompt="${promptColor}[az:$azgs]%{$reset_color%}%f "
  fi

  echo -en "${prompt}"
}

function __kubecontext() {
  local promptColor="%F{12}"
  if [ -d ~/.kube ] || [ -f "${KUBECONFIG}" ]; then
    local prompt="${promptColor}[$(kubectl config current-context)]%{$reset_color%} "
    local prompt=$(echo $prompt |sed "s/prod/%B%F{196}PROD%b%f${promptColor}/")
    echo -en "${prompt}"
  fi
}

function __gitprompt() {
  setopt local_options BASH_REMATCH
  local promptColor="%F{116}"
  local git_status="`git status -unormal 2>&1`"

  if ! [[ "$git_status" =~ not\ a\ git\ repo ]]; then
    # Status icon
    if [[ "$git_status" =~ nothing\ to\ commit ]]; then
      local statusIcon=""
    elif [[ "$git_status" =~ nothing\ added\ to\ commit\ but\ untracked\ files\ present ]]; then
      local statusIcon="${promptColor}✗%b%f"
    else
      local statusIcon="%{$fg_bold[yellow]%}✗%{$reset_color%}"
    fi

    # Set arrow icon based on status against remote.
    remote_pattern='Your branch (.*)(diverged|behind|ahead|up-to-date)(.*)'
    if [[ ${git_status} =~ ${remote_pattern} ]]; then
      case ${BASH_REMATCH[3]} in
          "diverged")
            local remoteIcon="%{$fg_bold[red]%}↓↑%{$reset_color%}"
            ;;        
          "ahead")
            local remoteIcon="${promptColor}↑%{$reset_color%}"
            ;;
          "behind")
            local remoteIcon="${promptColor}↓%{$reset_color%}"
            ;;
          *)
            local remoteIcon=""
            ;;
        esac
    fi
 
    if [[ "$git_status" =~ On\ branch\ ([^[:space:]]+) ]]; then
      branch=${BASH_REMATCH[2]}
    else
      # Detached HEAD. (branch=HEAD is a faster alternative.)
      branch="(`git describe --all --contains --abbrev=4 HEAD 2> /dev/null || echo HEAD`)"
    fi
 
    if [[ ! -z "${remoteIcon}${statusIcon}" ]]; then
      local separator=" "
    fi

    echo -ne "${promptColor}[${branch}${separator}${remoteIcon}${statusIcon}${promptColor}]%{$reset_color%}%f "
  fi
}

function __tfworkspace() {
  local promptColor="%F{99}"
  if [ -d .terraform ]; then
      local workspace="$(command terraform workspace show 2>/dev/null)"
  fi

  if [[ ! -z "${workspace}" ]]; then
    local prompt="${promptColor}[tf:$workspace]%{$reset_color%} "
  else
    local prompt=""
  fi
  echo -en "${prompt}"
}

function __virtualenv() {
  if type "pyenv" > /dev/null 2>&1; then
    local PYENV_VERSION_NAME=$(pyenv version-name)
    if [[ ${PYENV_VERSION_NAME} != "system" ]]; then
        echo -en "%F{142}(${PYENV_VERSION_NAME})%{$reset_color%} "
    fi
  fi
}

function __path() {
  echo -ne "%{$fg[cyan]%}%c%{$reset_color%} "
}

function __prompt() {
  echo -ne "%(!.#.$)%{$fg_bold[white]%}:%{$reset_color%} "
}

PROMPT=""
PROMPT+='$(__status)'
PROMPT+='$(__awsprofile)'
PROMPT+='$(__azinfo)'
PROMPT+='$(__kubecontext)'
PROMPT+='$(__virtualenv)'
PROMPT+='$(__tfworkspace)'
PROMPT+='$(__path)'
PROMPT+='$(__gitprompt)'
PROMPT+='$(__prompt)'

