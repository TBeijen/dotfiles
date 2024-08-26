# Even with ssh config stating UseKeyChain, somehow password prompt keeps appearing
# This seems to work.
# See: https://www.cyberciti.biz/faq/howto-fix-macos-keeps-asking-my-ssh-passphrase-since-i-updated-to-sierra/
ssh-add -A 2>/dev/null

# Adding path
PATH="/opt/homebrew/opt/curl/bin:$HOME/.local/bin/:$HOME/go/bin/:$PATH:$HOME/Library/Python/3.9/bin"

# nvm
export NVM_DIR="$HOME/.nvm"
  [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"

# pyenv
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
unset PYENV_SHELL
# See: https://github.com/pyenv/pyenv-virtualenv/blob/master/bin/pyenv-sh-activate
# Avoid entering pyenv dir to prepend venv name to zsh prompt
export PYENV_VIRTUALENV_DISABLE_PROMPT=1

export GPG_TTY=$(tty)
