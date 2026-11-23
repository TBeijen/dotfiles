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

# sopencode() {
#   local cmd=(fnox exec -- nono run --profile opencode-tb --allow-cwd -- opencode --standalone "$@")
#   # Exporting the startup command as env var. In case we need to experiment or troubleshoot by adding flags,
#   # we can get it via `! echo $SOPENCODE_CMD`
#   #
#   # Also outputing to stderr, which might be visible on launch or after TUI exits.
#   echo "→ ${cmd[*]}" >&2
#   export SOPENCODE_CMD="${cmd[*]}"
#   "${cmd[@]}"
# }

_sopencode_password() {
  local f="${XDG_STATE_HOME:-$HOME/.local/state}/sopencode/password"
  if [[ ! -s $f ]]; then
    mkdir -p "${f:h}"
    (umask 077; openssl rand -hex 24 > "$f")
  fi
  cat "$f"
}

sopencode() {
  local port=4096   # must match network.open_port in opencode-tb.json
  local url="http://127.0.0.1:$port"
  local logdir="${XDG_STATE_HOME:-$HOME/.local/state}/sopencode"
  local log="$logdir/server.log"
  local base=(fnox exec -- nono run --profile opencode-tb-sso --allow-cwd --)

  # Start the shared sandboxed server if nothing listens on the port yet.
  # The server picks a random password on each start and prints it to its log.
  if ! nc -z 127.0.0.1 $port 2>/dev/null; then
    mkdir -p "$logdir" && chmod 700 "$logdir"
    (umask 077; : > "$log")   # fresh, owner-only log per server start
    local server=("${base[@]}" opencode serve --port $port)
    echo "→ (server) ${server[*]}  [log: $log]" >&2
    nohup "${server[@]}" >>"$log" 2>&1 </dev/null &!
    local i
    for i in {1..50}; do
      grep -q 'server password' "$log" 2>/dev/null && break
      sleep 0.3
    done
  fi

  local pw="$(sed -n 's/.*server password \([^[:space:]]*\).*/\1/p' "$log" 2>/dev/null | tail -n1)"
  if [[ -z $pw ]]; then
    echo "no server password found in $log; if a server from an older run is still up, run sopencode-stop" >&2
    return 1
  fi

  # Exported rather than put on the command line, so it stays out of `ps`.
  local -x OPENCODE_PASSWORD="$pw"
  local cmd=("${base[@]}" opencode --server "$url" "$@")
  echo "→ ${cmd[*]}" >&2
  export SOPENCODE_CMD="${cmd[*]}"
  "${cmd[@]}"
}

sopencode-stop() {
  # Stops the shared sandboxed server; every attached TUI loses its connection.
  lsof -tiTCP:4096 -sTCP:LISTEN | xargs -r kill
}