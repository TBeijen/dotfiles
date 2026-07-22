# Opt-in: point AWS SDK at fnox-managed credentials file.
# Default: off — your normal ~/.aws/credentials (or SSO config) is used.
#
# To enable for a single session:
#   USE_FNOX_CREDS=true exec zsh
#
# To enable permanently, add to your shell init or set in workspace .envrc:
#   export USE_FNOX_CREDS=true
#
# When on, AWS SDK reads ~/.aws/fnox-credentials. fnox writes STS sessions
# (read-only + elevated) there as named profiles. Default ~/.aws/credentials
# stays untouched and remains usable when this is off.
if [[ "${USE_FNOX_CREDS:-false}" == "true" ]]; then
  export AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/fnox-credentials"
fi

# Drop into a subshell with fnox creds active, without touching the current shell.
# Useful when current shell uses normal AWS workflow and you just want to try fnox.
#   fnox-shell
fnox-shell() {
  USE_FNOX_CREDS=true AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/fnox-credentials"
"$SHELL"
}
