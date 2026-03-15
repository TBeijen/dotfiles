# ssh-add -A removed: no longer needed with UseKeychain yes + AddKeysToAgent yes
# in ~/.ssh/config. Keys are loaded lazily on first SSH use (~555ms startup saving).
# To revert, uncomment:
#   ssh-add -A 2>/dev/null

# Source secrets if available
# See .env-example for the secrets expected to exist
if [[ -f "$HOME/.env" ]]; then
  source "$HOME/.env"
fi

# Adding path
PATH="/opt/homebrew/opt/curl/bin:/opt/homebrew/opt/libpq/bin:$HOME/bin:$HOME/.local/bin/:$HOME/go/bin/:$PATH:$HOME/Library/Python/3.9/bin:/opt/podman/bin"

# pyenv: Cached init for fast shell startup (~649ms saving).
# The output of pyenv init is fairly static, so we cache it and regenerate daily.
# To revert to eager loading, replace this block with:
#
#   eval "$(pyenv init --path)"
#   eval "$(pyenv init -)"
#   eval "$(pyenv virtualenv-init -)"
#
_pyenv_cache="$HOME/.cache/pyenv-init.zsh"
if [[ ! -f "$_pyenv_cache" ]] || [[ $(date -r "$_pyenv_cache" +%s) -lt $(( $(date +%s) - 86400 )) ]]; then
  mkdir -p "$(dirname "$_pyenv_cache")"
  { pyenv init --path; pyenv init -; pyenv virtualenv-init - } > "$_pyenv_cache" 2>/dev/null
fi
source "$_pyenv_cache"
unset _pyenv_cache
unset PYENV_SHELL
# See: https://github.com/pyenv/pyenv-virtualenv/blob/master/bin/pyenv-sh-activate
# Avoid entering pyenv dir to prepend venv name to zsh prompt
export PYENV_VIRTUALENV_DISABLE_PROMPT=1

export GPG_TTY=$(tty)

# Enable zscaler-enabled bundle for common cli tools
zscaler_bundle_on

# tailscale
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

# nvm: Lazy-loaded to avoid ~1.8s shell startup penalty.
# Stub functions for nvm/node/npm/npx trigger the real nvm load on first use.
# To revert to eager loading, replace the lazy-load block below with:
#
#   export NVM_DIR="$HOME/.nvm"
#   [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
#   [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
#
# Note: eager loading enables automatic .nvmrc switching on cd, but adds ~600ms+
# to every shell startup.
export NVM_DIR="$HOME/.nvm"
_load_nvm() {
  unfunction nvm node npm npx 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { _load_nvm; nvm "$@" }
node() { _load_nvm; node "$@" }
npm()  { _load_nvm; npm "$@" }
npx()  { _load_nvm; npx "$@" }

# shortcuts
# CUHD: CUrl Header Dump (array, expanded into multiple args, not a single arg)
export CUHD=(-s -D - -o /dev/null)  
# CUAD: CUrl Akamai Debug (most common debug headers)
# CUADF: CUrl Akamai Debug Full (all debug headers)
export CUAD=(-H "x-dpgm-akdebug-unhide: $DPG_AKAMAI_UNHIDE" -H "pragma: akamai-x-im-trace, akamai-x-cache-on, akamai-x-cache-remote-on, akamai-x-check-cacheable, akamai-x-get-cache-key, akamai-x-get-true-cache-key, akamai-x-serial-no, akamai-x-get-request-id, akamai-x-get-client-ip")
export CUADF=(-H "x-dpgm-akdebug-unhide: $DPG_AKAMAI_UNHIDE" -H "pragma: akamai-x-im-trace, akamai-x-cache-on, akamai-x-cache-remote-on, akamai-x-check-cacheable, akamai-x-get-cache-key, akamai-x-get-true-cache-key, akamai-x-serial-no, akamai-x-get-request-id, x-akamai-a2-trace, akamai-x-tapioca-trace, akamai-x-get-extracted-values, x-akamai-rua-debug, akamai-x-get-brotli-status, akamai-x-feo-trace, akamai-x-ro-trace, akamai-x-im-trace, akamai-x-ew-debug, akamai-x-ew-debug-rp, akamai-x-ew-debug-subs, akamai-x-ew-onclientrequest, akamai-x-ew-onoriginrequest, akamai-x-ew-onoriginresponse, akamai-x-ew-onclientresponse, akamai-x-get-brotli-status, akamai-x-get-nonces, akamai-x-get-ssl-client-session-id, akamai-x-get-client-ip")
# shortcuts end

# pnpm
export PNPM_HOME="/Users/tbeijen01/Library/pnpm"
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