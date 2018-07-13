# ~/.bashrc
# this file gets sourced by ~/.bash_profile

# --------------------------------------------------------------------------- #
# Basic setup
# --------------------------------------------------------------------------- #

# set INPUTRC (so that .inputrc is respected)
export INPUTRC=~/.inputrc

# add various directories to PATH
PATH=~/bin:/usr/local/bin:/usr/local/sbin:$PATH
PATH=/usr/local/terraform:$PATH
PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
export PATH="/usr/local/opt/openssl/bin:$PATH"

# Configure prompt
source ~/dotfiles/common/prompt.sh

# Kube config, allowing multiple config files. Initially load all configs.
# Explicitly loading default.config first, using it to specify the default context
# which is the first current-context encountered (See: https://coreos.com/blog/kubectl-tips-and-tricks)
export KUBECONFIG="~/.kube/default.config:$(find ~/.kube -type f -name '*.config'  | tr '\n' ':')"

# locale (needed for sphynx)
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Load RVM into a shell session *as a function*
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

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

export PYENV_ROOT="/Users/tibobeijen/.pyenv"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

source ~/dotfiles/common/aws_scripts.sh
source ~/dotfiles/common/kube_scripts.sh
source ~/dotfiles/common/scripts.sh

# --------------------------------------------------------------------------- #
# History
# --------------------------------------------------------------------------- #
export HISTCONTROL=erasedups
export HISTSIZE=10000
shopt -s histappend
