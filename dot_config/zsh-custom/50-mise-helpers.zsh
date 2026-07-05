# mise helper functions

# Bump one or more mise-managed tools to their latest version, re-pin in
# ~/.config/mise/config.toml, sync to chezmoi source, and optionally commit.
#
# Usage: mise-bump <tool> [tool2 ...]
# Example: mise-bump claude starship gh
mise-bump() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: mise-bump <tool> [tool2 ...]"
    return 1
  fi

  local config="$HOME/.config/mise/config.toml"
  local before
  before=$(cat "$config" 2>/dev/null)

  local any_failed=0
  for tool in "$@"; do
    local latest_version
    latest_version=$(mise latest "$tool" 2>/dev/null)
    if [[ -z "$latest_version" ]]; then
      echo "✗ $tool: could not determine latest version"
      any_failed=1
      continue
    fi
    if ! mise use -g "$tool@$latest_version" >/dev/null; then
      echo "✗ $tool: install failed (config.toml may have been modified — verify with 'mise current $tool')"
      any_failed=1
      continue
    fi
    echo "✓ $tool → $latest_version"
  done

  if (( any_failed )); then
    echo ""
    echo "⚠  Some tools failed. Fix and rerun before committing."
    return 1
  fi

  local after
  after=$(cat "$config")

  if [[ "$before" == "$after" ]]; then
    echo ""
    echo "No changes to $config — all tools were already pinned to latest."
    return 0
  fi

  # Show what changed
  echo ""
  echo "Changes in $config:"
  diff <(printf '%s' "$before") <(printf '%s' "$after") | grep -E "^[<>]" | sed 's/^/  /'

  # Sync to chezmoi source explicitly (the apply.pre hook also does this,
  # but doing it here makes the workflow self-contained)
  if ! command -v chezmoi &>/dev/null; then
    echo ""
    echo "WARN: chezmoi not found — skipping source sync"
    return 0
  fi
  chezmoi re-add ~/.config/mise/config.toml ~/.config/mise/mise.lock 2>/dev/null
  echo ""
  echo "✓ Re-added to chezmoi source"

  # Offer to commit
  local chezmoi_dir
  chezmoi_dir=$(chezmoi source-path)
  if [[ ! -d "$chezmoi_dir/.git" ]]; then
    return 0
  fi

  printf "Commit and push to chezmoi source? [y/N] "
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    return 0
  fi

  git -C "$chezmoi_dir" add dot_config/mise/config.toml dot_config/mise/mise.lock 2>/dev/null
  git -C "$chezmoi_dir" commit -m "mise bump: $*"
  echo "✓ Committed"

  if git -C "$chezmoi_dir" push; then
    echo "✓ Pushed"
  else
    echo "✗ Push failed — commit is local only; you can retry manually from $chezmoi_dir"
    return 1
  fi
}

# Run `mise up -i` (interactive tool version updates), then re-sync the global
# mise config + lockfile into chezmoi source, and optionally commit + push.
#
# Usage: mise-up [<mise up args>]
# Extra args are passed through to mise up (e.g. --dry-run, specific tool names).
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
