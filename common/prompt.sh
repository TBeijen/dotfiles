#!/bin/bash
source ~/dotfiles/common/colors.sh

# Status of last command (for prompt)
function __stat() { 
    if [ $? -eq 0 ]; then 
        echo -en "${green}[✔]${reset} " 
    else 
        echo -en "${red}[✘]${reset} "
    fi 
} 

function __awsprofile() {
  if [ -z $AWS_PROFILE ]; then
      echo -en "${orange}${bold}[default]${reset} "
  else
      echo -en "${orange}${bold}[$AWS_PROFILE]${reset} "
  fi
}

function __kube_context() {
  if [ -d ~/.kube ]; then
    echo -en "${blue}${bold}[$(kubectl config current-context)]${reset} "
  fi
}

function __virtualenv() {
  # python virtualenv (old implementation)
  if [ -z "$VIRTUAL_ENV" ]; then
      echo -en ""
  else
      echo -en "${yellow}(`basename \"$VIRTUAL_ENV\"`)${reset} "
  fi

  # recent pyenv
  if type "pyenv" > /dev/null 2>&1; then
    local PYENV_VERSION_NAME=$(pyenv version-name)
    if [[ ${PYENV_VERSION_NAME} != "system" ]]; then
        echo -en "${yellow}(${PYENV_VERSION_NAME})${reset} "
    fi
fi
}

# Display the branch name of git repository
# Green -> clean
# purple -> untracked files
# red -> files to commit
function __git_prompt() {
 
    local git_status="`git status -unormal 2>&1`"
 
    if ! [[ "$git_status" =~ Not\ a\ git\ repo ]]; then
        if [[ "$git_status" =~ nothing\ to\ commit ]]; then
            local Color_On=${green}
        elif [[ "$git_status" =~ nothing\ added\ to\ commit\ but\ untracked\ files\ present ]]; then
            local Color_On=${purple}
        else
            local Color_On=${red}
        fi

				# Set arrow icon based on status against remote.
				remote_pattern='Your branch is (behind|ahead|up-to-date)(.*)'
				if [[ ${git_status} =~ ${remote_pattern} ]]; then
						case ${BASH_REMATCH[1]} in
							"ahead")
								remote="↑"
								;;
							"behind")
								remote="↓"
								;;
							*)
								remote=""
								;;
						esac
				fi
 
        if [[ "$git_status" =~ On\ branch\ ([^[:space:]]+) ]]; then
            branch=${BASH_REMATCH[1]}
        else
            # Detached HEAD. (branch=HEAD is a faster alternative.)
            branch="(`git describe --all --contains --abbrev=4 HEAD 2> /dev/null || echo HEAD`)"
        fi
 
        echo -ne "$Color_On[$branch]${remote}${reset} "
    fi
}

function make_prompt {

  PS1=""
  PS1+='$(__stat)'
  PS1+='$(__awsprofile)'
  PS1+='$(__kube_context)'
  PS1+='$(__virtualenv)'
  PS1+="\W "
  # add git display to prompt
  PS1+='$(__git_prompt)'
  PS1+="\$${bold}:${reset} "

  PS2="${bold}>${reset} "
}
PROMPT_COMMAND=make_prompt
