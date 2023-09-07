# Even with ssh config stating UseKeyChain, somehow password prompt keeps appearing
# This seems to work.
# See: https://www.cyberciti.biz/faq/howto-fix-macos-keeps-asking-my-ssh-passphrase-since-i-updated-to-sierra/
ssh-add -A 2>/dev/null

# Adding path
PATH="$HOME/.local/bin/:$PATH:$HOME/Library/Python/3.9/bin"

# nvm
export NVM_DIR="$HOME/.nvm"
  [ -s "/usr/local/opt/nvm/nvm.sh" ] && \. "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/usr/local/opt/nvm/etc/bash_completion.d/nvm"

export GPG_TTY=$(tty)
  