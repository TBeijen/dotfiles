# Shows help message.
#  $1: The help message
#  $2: Whether to show the help message also on empty args list
#  $3...$n: Original functions arg list
#
# Call from shell function. Example:
# my_func()
#   _show_help "$(cat <<-HELP
#     the help
#     message
# HELP
# )" 1 "$@" || return 0
#   
#   # ... function code
# } 
_show_help() {
  if [[ "$3" == "-h" ]] || [[ "$3" == "--help" ]] || [[ "$2" == "1" && "$#" -lt 3 ]]; then
    echo "$1"
    return 1
  fi
}

# Recursively clean all python cache files from current dir
# @see https://stackoverflow.com/a/41386937
pyclean () {
    find . -type f -name '*.py[co]' -delete -o -type d -name __pycache__ -delete
}



# In-depth info about deleting branches: https://stackoverflow.com/questions/2003505/how-do-i-delete-a-git-branch-locally-and-remotely
git_merged() {
  _show_help "$(cat <<-HELP
Show or remove merged branches, either local or remote, from the repository the local dir is in.

Usage:
  git_merged show|delete local|remote|all

  git_merged show all
  
  # nothing unusual there?
  # (Or, if you have other intends, run the output of the above command through xargs...)

  git_merged delete all
HELP
  )" 1 "$@" || return 0

  # subshell, so -e exits function, not terminal
  (
    set -e

    MAIN_BRANCH=$({ git for-each-ref --format='%(refname:short)' refs/heads/master;
      git for-each-ref --format='%(refname:short)' refs/heads/main;
    } | head -1)

    # Script constants
    BRANCH_WHITELIST="(\*|master|main|develop)"
    REMOTES="origin"  # Add more remotes here as space-separated list

    # local
    if [[ $2 == "local" || $2 == "all" ]]; then
      for branch in $(git branch --merged $MAIN_BRANCH | egrep -v "$BRANCH_WHITELIST"); do
        if [[ $1 == "show" ]]; then echo "${branch}"; fi
        if [[ $1 == "delete" ]]; then git branch -d "${branch}"; fi
      done
    fi

    # remotes
    if [[ $2 == "remote" || $2 == "all" ]]; then
      for remote in "$REMOTES"; do
        git fetch "$remote" --prune
        for branch in $(git branch -r --merged $MAIN_BRANCH | grep "$remote" | egrep -v "$BRANCH_WHITELIST"); do
          if [[ $1 == "show" ]]; then echo "${branch}"; fi
          #  '#*/' part removes the preceding 'origin/' part from the branch name
          if [[ $1 == "delete" ]]; then git push "${remote}" --delete --no-verify "${branch#*/}"; fi
        done
      done
    fi
  )
}

