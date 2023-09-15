# Wrapper for terraform that automatically appends vars-file based on workspace
# @TODO improve way of detecting whether command actually suports -var-file arg.
tf() {
  if [ -d .terraform ]; then
    echo "$@"
    if echo "$@" | grep -qE "plan|apply|destroy"; then
      local workspace="$(command terraform workspace show 2>/dev/null)"
      local vars_arg="-var-file=$(command terraform workspace show 2>/dev/null).tfvars"
    fi
  fi
  command terraform "$@" ${vars_arg}
}
