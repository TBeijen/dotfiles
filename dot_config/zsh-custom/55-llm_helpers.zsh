sclaude() {
  local cmd=(fnox exec -- nono run --profile claude-code-tb-sso --allow-cwd -- claude "$@")
  # Exporting the startup command as env var. In case we need to experiment or troubleshoot by adding flags,
  # we can get it via `! echo $SCLAUDE_CMD`
  #
  # Also outputing to stderr, which might be visible on launch or after TUI exits.
  echo "→ ${cmd[*]}" >&2
  export SCLAUDE_CMD="${cmd[*]}"
  "${cmd[@]}"
}
