# Source additional scripts symlinked from other repositories
setopt NULL_GLOB
for f in $HOME/.config/zsh-custom/sourced/*; do source $f; done
unsetopt NULL_GLOB