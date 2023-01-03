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
      local prompt="${promptColor}[default]%{$reset_color%} "
  else
      local prompt="${promptColor}[$AWS_PROFILE]%{$reset_color%} "
  fi

  local prompt=$(echo $prompt |sed "s/prod/%B%F{196}PROD%b%f${promptColor}/")
  echo -en "${prompt}"
}

function __kubecontext() {
  local promptColor="%F{12}"
  if [ -d ~/.kube ] && [ -f "${KUBECONFIG}" ]; then
    local prompt="${promptColor}[$(kubectl config current-context)]%{$reset_color%} "
    local prompt=$(echo $prompt |sed "s/prod/%B%F{196}PROD%b%f${promptColor}/")
    echo -en "${prompt}"
  fi
}

function __gitprompt() {
  setopt local_options BASH_REMATCH
  local promptColor="%F{116}"
  local git_status="`git status -unormal 2>&1`"

  if ! [[ "$git_status" =~ Not\ a\ git\ repo ]]; then
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

    echo -ne "${promptColor}[${branch}${separator}${remoteIcon}${statusIcon}${promptColor}]%{$reset_color%} "
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
PROMPT+='$(__kubecontext)'
PROMPT+='$(__path)'
PROMPT+='$(__gitprompt)'
PROMPT+='$(__prompt)'

