# ~/.bashrc
# this file gets sourced by ~/.bash_profile

# --------------------------------------------------------------------------- #
# Basic setup
# --------------------------------------------------------------------------- #

# set INPUTRC (so that .inputrc is respected)
export INPUTRC=~/.inputrc

# add various directories to PATH
PATH=/usr/local/opt/mysql@5.6/bin:$PATH
PATH=~/bin:/usr/local/bin:/usr/local/sbin:$PATH
PATH=/usr/local/terraform:$PATH
PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
export PATH="/usr/local/opt/openssl/bin:$PATH"

# Configure prompt
# Note: Disabled, delegating to kubernetes repo
# source ~/dotfiles/common/prompt.sh


if command -v pyenv 1>/dev/null 2>&1; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
fi

# Source additional scripts symlinked from other repositories
# TODO: Figure out why having prompt script sourced at end prevents VIRTUAL_ENV from being set (and by that, venv name being visible in prompt)
for f in ~/dotfiles/sourced_scripts/*; do source $f; done

# Kube config, allowing multiple config files. Initially load all configs.
# Explicitly loading default.config first, using it to specify the default context
# which is the first current-context encountered (See: https://coreos.com/blog/kubectl-tips-and-tricks)
export KUBECONFIG="$HOME/.kube/default.config"

# Running Helm Tiller component local by default
export HELM_HOST=localhost:44134

# locale (needed for sphynx)
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Load RVM into a shell session *as a function*
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# Fixing SOPS-GPG integration
# See: https://github.com/mozilla/sops/issues/304#issuecomment-377195341
GPG_TTY=$(tty)
export GPG_TTY

# asdf
# (echo -e "\n. $(brew --prefix asdf)/libexec/asdf.sh")
. /usr/local/opt/asdf/libexec/asdf.sh

# --------------------------------------------------------------------------- #
# Aliases and auto completion
# --------------------------------------------------------------------------- #
alias ll="ls -lahG"

# Auto-complete ssh command based on both known_hosts and ssh config
SSH_HOSTS_KNOWN="$(echo `cat ~/.ssh/known_hosts | cut -f 1 -d ' ' | sed -e s/,.*//g | uniq | grep -v "\["`;)"
SSH_HOSTS_CONFIG=$(perl -ne 'print "$1 " if /^Host (.+)$/' ~/.ssh/config)
SSH_HOSTS="$SSH_HOSTS_KNOWN $SSH_HOSTS_CONFIG"
complete -o plusdirs -o filenames -W "$SSH_HOSTS" scp 
complete -W "$SSH_HOSTS" ssh 

source ~/dotfiles/common/scripts.sh
# Note: Disabled, delegating to kubernetes repo
# source ~/dotfiles/common/set_workspace.sh
source ~/dotfiles/common/aws_scripts.sh
source ~/dotfiles/common/kube_scripts.sh

# --------------------------------------------------------------------------- #
# History
# --------------------------------------------------------------------------- #
export HISTCONTROL=erasedups
export HISTSIZE=10000
shopt -s histappend
