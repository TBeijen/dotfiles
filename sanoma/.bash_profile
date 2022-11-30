# source common .bash_profile
if [ -f ~/dotfiles/common/.bash_profile ]; then
   source ~/dotfiles/common/.bash_profile
fi

# pipx, poetry
export PATH="$HOME/.local/bin:$HOME/.poetry/bin:$PATH"
