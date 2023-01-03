# Status of last command
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




#PROMPT="%(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ )"
# command status
# PROMPT="%(?:%{$fg[green]%}[✔]%{$reset_color%} :%{$fg[red]%}[✘]%{$reset_color%} )"
PROMPT=""
PROMPT+='$(__status)'
PROMPT+='$(__awsprofile)'
PROMPT+='$(__kubecontext)'

PROMPT+='%{$fg[cyan]%}%c%{$reset_color%} $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}✗"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"


# info:
# https://dev.to/yujinyuz/custom-colors-in-oh-my-zsh-themes-4h13