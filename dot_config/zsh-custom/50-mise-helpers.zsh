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

  for tool in "$@"; do
    local latest_version
    latest_version=$(mise latest "$tool" 2>/dev/null)
    if [[ -z "$latest_version" ]]; then
      echo "✗ $tool: could not determine latest version"
      continue
    fi
    mise use -g "$tool@$latest_version" >/dev/null
    echo "✓ $tool → $latest_version"
  done

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
  chezmoi re-add ~/.config/mise/config.toml >/dev/null
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

  git -C "$chezmoi_dir" add dot_config/mise/config.toml
  git -C "$chezmoi_dir" commit -m "mise bump: $*"
  echo "✓ Committed"

  if git -C "$chezmoi_dir" push; then
    echo "✓ Pushed"
  else
    echo "✗ Push failed — commit is local only; you can retry manually from $chezmoi_dir"
    return 1
  fi
}
