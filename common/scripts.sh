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

# Git command specific for DPG, using the SSH key needed for DPG GitHub organization.
# Only needed for initial clone, after clone, the gitconfig IncludeIf gitdir, will accomplish the same:
# Using the dpg ssh key without first trying the default, which GitHub will happily accept, but then deny access to the org repo.
git_dpg() {
  GIT_SSH_COMMAND='ssh -o IdentityAgent=none -o IdentitiesOnly=yes -i ~/.ssh/dpg_id_ed25519' git "$@"
}

# Convert markdown to rich text and copy to clipboard.
# Use case: Shitty Jira that is not configured to accept markdown, but does accept rich text from clipboard.
#
# Source: https://www.samuelliedtke.com/blog/til-convert-markdown-to-rich-text-and-copy-to-clipboard-on-macos (adapted with ChatGPT)
function md2pb() {
  emulate -L zsh
  set -o pipefail

  # Read input: from stdin if piped, else from first arg
  local md
  if [[ -t 0 ]]; then
    if [[ $# -eq 0 ]]; then
      echo "Usage: md2pb [markdown-file]  (or: cat file.md | md2pb)" >&2
      return 64
    fi
    md=$(cat -- "$1") || return $?
  else
    md=$(cat) || return $?
  fi

  # Check deps
  for cmd in pandoc osascript hexdump; do
    command -v "$cmd" >/dev/null || { echo "md2pb: missing dependency: $cmd" >&2; return 127; }
  done

  # Markdown -> HTML fragment (GitHub-flavored + smart punctuation)
  local html hex
  html=$(printf '%s' "$md" | pandoc -f gfm+smart -t html) || return $?

  # Hex-encode for AppleScript's «data HTML…» literal
  hex=$(printf '%s' "$html" | hexdump -ve '1/1 "%.2x"') || return $?

  # Markdown -> Plain text (smart punctuation)
  local plain
  plain=$(printf '%s' "$md" | pandoc -f gfm+smart -t plain) || return $?
  # Escape double quotes for AppleScript
  plain=${plain//\"/\\\"}

  # Set clipboard with both plain text and rich HTML flavors
  printf 'set the clipboard to {text:"%s", «class HTML»:«data HTML%s»}\n' "$plain" "$hex" | osascript - >/dev/null
}