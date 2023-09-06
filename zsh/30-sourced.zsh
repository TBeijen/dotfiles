# Source additional scripts symlinked from other repositories
setopt NULL_GLOB
for f in $HOME/dotfiles/zsh/sourced/*; do source $f; done
unsetopt NULL_GLOB