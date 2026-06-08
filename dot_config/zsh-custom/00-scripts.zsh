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

aws-logins() {
  # Configuration
  local AWS_REGION="${AWS_REGION:-eu-west-1}"
  local ECR_REGISTRY="${1:-952653322924.dkr.ecr.eu-west-1.amazonaws.com}"
  
  echo "🔐 Starting AWS ECR login process..."
  
  # Step 1: Check if AWS SSO session is still valid
  echo "\n📝 Step 1: Checking AWS SSO session"
  if aws sts get-caller-identity &> /dev/null; then
    echo "✅ AWS SSO session is still valid"
  else
    echo "⚠️  AWS SSO session expired or not authenticated"
    echo "🌐 Opening browser for SSO login..."
    if ! aws sso login; then
      echo "❌ AWS SSO login failed"
      return 1
    fi
    echo "✅ AWS SSO login successful"
  fi
  
  # Get ECR password
  echo "\n🔑 Retrieving ECR credentials..."
  local ECR_PASSWORD
  ECR_PASSWORD=$(aws ecr get-login-password --region "$AWS_REGION")
  
  if [ -z "$ECR_PASSWORD" ]; then
    echo "❌ Failed to retrieve ECR password"
    return 1
  fi
  
  # Step 2: Helm registry login
  echo "\n📦 Step 2: Helm registry login"
  if echo "$ECR_PASSWORD" | helm registry login \
      --username AWS \
      --password-stdin "$ECR_REGISTRY"; then
    echo "✅ Helm registry login successful"
  else
    echo "⚠️  Helm registry login failed"
  fi
  
  # Step 3: Skopeo login
  echo "\n🐙 Step 3: Skopeo login"
  if echo "$ECR_PASSWORD" | skopeo login \
      --username AWS \
      --password-stdin "$ECR_REGISTRY"; then
    echo "✅ Skopeo login successful"
  else
    echo "⚠️  Skopeo login failed"
  fi
  
  # Step 4: Podman login
  echo "\n🦭 Step 4: Podman login"
  
  # Check if podman machine is running
  if command -v podman &> /dev/null; then
    if podman machine list 2>/dev/null | grep -q "Currently running"; then
      echo "✓ Podman machine is running"
    else
      echo "⚠️  Podman machine is not running. Starting it..."
      podman machine start
    fi
    
    if echo "$ECR_PASSWORD" | podman login \
        --username AWS \
        --password-stdin "$ECR_REGISTRY"; then
      echo "✅ Podman login successful"
    else
      echo "⚠️  Podman login failed"
    fi
  else
    echo "⚠️  Podman not found, skipping..."
  fi
  
  # Step 5: Crane login
  echo "\n🏗️  Step 5: Crane login"
  if command -v crane &> /dev/null; then
    if echo "$ECR_PASSWORD" | crane auth login \
        --username AWS \
        --password-stdin "$ECR_REGISTRY"; then
      echo "✅ Crane login successful"
    else
      echo "⚠️  Crane login failed"
    fi
  else
    echo "⚠️  Crane not found, skipping..."
  fi
  
  echo "\n✨ AWS ECR login process completed!"
}