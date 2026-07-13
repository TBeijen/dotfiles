#!/usr/bin/env bash
# Claude Code statusline command
# Mirrors the tbnl zsh theme: path, git branch/status, model, context usage

input=$(cat)

# Extract fields from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# -- Path (basename, like %c in zsh theme) --
dir_part=$(basename "$cwd")

# -- Git info (skip optional locks) --
git_status=$(git -C "$cwd" -c gc.auto=0 status -unormal 2>&1)
git_part=""
if ! echo "$git_status" | grep -q "not a git repo\|not a git repository"; then
  branch=""
  if echo "$git_status" | grep -q "^On branch "; then
    branch=$(echo "$git_status" | grep "^On branch " | sed 's/^On branch //')
  else
    branch=$(git -C "$cwd" describe --all --contains --abbrev=4 HEAD 2>/dev/null || echo "HEAD")
  fi

  status_icon=""
  if echo "$git_status" | grep -q "nothing to commit"; then
    status_icon=""
  elif echo "$git_status" | grep -q "nothing added to commit but untracked files present"; then
    status_icon="?"
  else
    status_icon="*"
  fi

  remote_icon=""
  if echo "$git_status" | grep -q "diverged"; then
    remote_icon="↓↑"
  elif echo "$git_status" | grep -q "ahead"; then
    remote_icon="↑"
  elif echo "$git_status" | grep -q "behind"; then
    remote_icon="↓"
  fi

  suffix="${remote_icon}${status_icon}"
  if [ -n "$suffix" ]; then
    git_part="[${branch} ${suffix}]"
  else
    git_part="[${branch}]"
  fi
fi

# -- Model --
model_part=""
if [ -n "$model" ]; then
  model_part="$model"
fi

# -- Context usage --
ctx_part=""
if [ -n "$used_pct" ]; then
  ctx_part=$(printf "ctx:%.0f%%" "$used_pct")
fi

# -- Cost --
cost_part=""
if [ -n "$cost_usd" ]; then
  cost_part=$(printf '$%.3f' "$cost_usd")
fi

# -- Assemble with ANSI colors (dimmed-friendly) --
# cyan for path, default for git, dim for model/ctx
reset="\033[0m"
cyan="\033[36m"
yellow="\033[33m"
dim="\033[2m"

parts=""

# path
parts="${cyan}${dir_part}${reset}"

# git
if [ -n "$git_part" ]; then
  parts="${parts} ${yellow}${git_part}${reset}"
fi

# model + context
meta=""
if [ -n "$model_part" ]; then
  meta="$model_part"
fi
if [ -n "$ctx_part" ]; then
  if [ -n "$meta" ]; then
    meta="${meta} ${ctx_part}"
  else
    meta="$ctx_part"
  fi
fi
if [ -n "$cost_part" ]; then
  if [ -n "$meta" ]; then
    meta="${meta} ${cost_part}"
  else
    meta="$cost_part"
  fi
fi
if [ -n "$meta" ]; then
  parts="${parts} ${dim}${meta}${reset}"
fi

printf "%b" "$parts"
