#!/usr/bin/env bash
set -euo pipefail

NONO_ARGS=("$@")
if [[ ${#NONO_ARGS[@]} -eq 0 ]]; then
  if [[ -n "${NONO_CAP_FILE:-}" ]]; then
    NONO_ARGS=(--self)
    echo "Running inside sandbox (autodetect)"
  else
    echo "Running outside sandbox (autodetect)"
  fi
else
  echo "Running with args: ${NONO_ARGS[*]}"
fi
echo ""

PASS_COUNT=0
FAIL_COUNT=0

sandbox_test() {
  local actual="$1"
  local op="$2"
  local expected="$3"
  local description="${4:-$actual $op $expected}"

  local result=false
  case "$op" in
    =|==) [[ "$actual" == "$expected" ]] && result=true ;;
    !=)   [[ "$actual" != "$expected" ]] && result=true ;;
    *)    echo "Unknown operator: $op"; exit 1 ;;
  esac

  if $result; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '\033[32m✔ PASS\033[0m - %s\n' "$description"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '\033[31m✘ FAIL\033[0m - %s (got: %s)\n' "$description" "$actual"
  fi
}

summary() {
  echo ""
  echo "──────────────────────────────────"
  local total=$((PASS_COUNT + FAIL_COUNT))
  printf '%d tests: \033[32m%d passed\033[0m' "$total" "$PASS_COUNT"
  if [[ $FAIL_COUNT -gt 0 ]]; then
    printf ', \033[31m%d failed\033[0m' "$FAIL_COUNT"
  fi
  echo ""

  [[ $FAIL_COUNT -eq 0 ]]
}

# --- path helpers ---
path_status() { nono why "${NONO_ARGS[@]}" --path "$1" --json | jq -r .status; }

assert_path_denied() {
  sandbox_test "$(path_status "$1")" = "denied" "path $1 is denied"
}

assert_path_allowed() {
  sandbox_test "$(path_status "$1")" = "allowed" "path $1 is allowed"
}

# --- Tests ---

assert_path_denied ~/.aws
assert_path_denied ~/.ssh
assert_path_denied ~/Documents
assert_path_denied ~/Downloads

summary
