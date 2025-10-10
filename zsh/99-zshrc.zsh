# Even with ssh config stating UseKeyChain, somehow password prompt keeps appearing
# This seems to work.
# See: https://www.cyberciti.biz/faq/howto-fix-macos-keeps-asking-my-ssh-passphrase-since-i-updated-to-sierra/
ssh-add -A 2>/dev/null

# Source secrets if available
# See .env-example for the secrets expected to exist
if [[ -f "$HOME/.env" ]]; then
  source "$HOME/.env"
fi

# Adding path
PATH="/opt/homebrew/opt/curl/bin:$HOME/bin:$HOME/.local/bin/:$HOME/go/bin/:$PATH:$HOME/Library/Python/3.9/bin:/opt/podman/bin"

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

# Enable zscaler-enabled bundle for common cli tools
zscaler_bundle_on

# tailscale
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# shortcuts
# CUHD: CUrl Header Dump (array, expanded into multiple args, not a single arg)
export CUHD=(-s -D - -o /dev/null)  
# CUAD: CUrl Akamai Debug (most common debug headers)
# CUADF: CUrl Akamai Debug Full (all debug headers)
export CUAD=(-H "x-dpgm-akdebug-unhide: $DPG_AKAMAI_UNHIDE" -H "pragma: akamai-x-im-trace, akamai-x-cache-on, akamai-x-cache-remote-on, akamai-x-check-cacheable, akamai-x-get-cache-key, akamai-x-get-true-cache-key, akamai-x-serial-no, akamai-x-get-request-id, akamai-x-get-client-ip")
export CUADF=(-H "x-dpgm-akdebug-unhide: $DPG_AKAMAI_UNHIDE" -H "pragma: akamai-x-im-trace, akamai-x-cache-on, akamai-x-cache-remote-on, akamai-x-check-cacheable, akamai-x-get-cache-key, akamai-x-get-true-cache-key, akamai-x-serial-no, akamai-x-get-request-id, x-akamai-a2-trace, akamai-x-tapioca-trace, akamai-x-get-extracted-values, x-akamai-rua-debug, akamai-x-get-brotli-status, akamai-x-feo-trace, akamai-x-ro-trace, akamai-x-im-trace, akamai-x-ew-debug, akamai-x-ew-debug-rp, akamai-x-ew-debug-subs, akamai-x-ew-onclientrequest, akamai-x-ew-onoriginrequest, akamai-x-ew-onoriginresponse, akamai-x-ew-onclientresponse, akamai-x-get-brotli-status, akamai-x-get-nonces, akamai-x-get-ssl-client-session-id, akamai-x-get-client-ip")
# shortcuts end

# pnpm
export PNPM_HOME="/Users/tibobeijen/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# oh-my-posh
if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
  # eval "$(oh-my-posh init zsh --config "$HOME/dotfiles/oh-my-posh-themes/froczah.json")"
  # eval "$(oh-my-posh init zsh --config "$HOME/dotfiles/oh-my-posh-themes/new_config.omp.json")"
  eval "$(oh-my-posh init zsh --config "$HOME/dotfiles/oh-my-posh-themes/tbnl-default.json")"
fi
# oh-my-posh end