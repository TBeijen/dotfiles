# mise helper functions

# Run `mise up -i` (interactive tool version updates), then re-sync the global
# mise config + lockfile into chezmoi source, and optionally commit + push.
#
# Usage: mise-up [<mise up args>]
# Examples:
#   mise-up               # interactive upgrade within current constraints
#   mise-up --bump        # also bump the constraints themselves
#   mise-up node python   # only these tools
mise-up() {
  echo "==> mise up -i $*"
  mise up -i "$@" || return 1

  if ! command -v chezmoi &>/dev/null; then
    echo ""
    echo "WARN: chezmoi not found — skipping source sync"
    return 0
  fi

  chezmoi re-add ~/.config/mise/config.toml ~/.config/mise/mise.lock 2>/dev/null

  local chezmoi_dir
  chezmoi_dir=$(chezmoi source-path)
  if [[ ! -d "$chezmoi_dir/.git" ]]; then
    return 0
  fi

  if git -C "$chezmoi_dir" diff --quiet dot_config/mise/; then
    echo ""
    echo "No changes to mise config in chezmoi source — tools were already at target versions."
    return 0
  fi

  echo ""
  echo "Changes to commit:"
  git -C "$chezmoi_dir" diff --stat dot_config/mise/ | sed 's/^/  /'

  printf "Commit and push to chezmoi source? [y/N] "
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    return 0
  fi

  git -C "$chezmoi_dir" add dot_config/mise/config.toml dot_config/mise/mise.lock 2>/dev/null
  git -C "$chezmoi_dir" commit -m "mise up: bump tool versions"
  echo "✓ Committed"

  if git -C "$chezmoi_dir" push; then
    echo "✓ Pushed"
  else
    echo "✗ Push failed — commit is local only; you can retry manually from $chezmoi_dir"
    return 1
  fi
}
