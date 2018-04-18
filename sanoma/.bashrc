# source common .bashrc
if [ -f ~/dotfiles/common/.bashrc ]; then
   source ~/dotfiles/common/.bashrc
fi


export GOPATH=~/projects/go_repos/

# BFG Repo-Cleaner
alias bfg="java -jar ~/bin/bfg.jar"


# --------------------------------------------------------------------------- #
# Applications
# --------------------------------------------------------------------------- #

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/tibobeijen/google-cloud-sdk/path.bash.inc' ]; then source '/Users/tibobeijen/google-cloud-sdk/path.bash.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/tibobeijen/google-cloud-sdk/completion.bash.inc' ]; then source '/Users/tibobeijen/google-cloud-sdk/completion.bash.inc'; fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# tabtab source for serverless package
# uninstall by removing these lines or running `tabtab uninstall serverless`
[ -f /Users/tibobeijen/.nvm/versions/node/v8.4.0/lib/node_modules/serverless/node_modules/tabtab/.completions/serverless.bash ] && . /Users/tibobeijen/.nvm/versions/node/v8.4.0/lib/node_modules/serverless/node_modules/tabtab/.completions/serverless.bash
# tabtab source for sls package
# uninstall by removing these lines or running `tabtab uninstall sls`
[ -f /Users/tibobeijen/.nvm/versions/node/v8.4.0/lib/node_modules/serverless/node_modules/tabtab/.completions/sls.bash ] && . /Users/tibobeijen/.nvm/versions/node/v8.4.0/lib/node_modules/serverless/node_modules/tabtab/.completions/sls.bash