# Copies kubernetes dashboard bearer token to clipboard
kube_get_token() {
  kubectl -n kube-system get secrets -o json|jq '.items[0].data.token'|tr -d '"'|base64 -D| pbcopy
  echo "Token copied to clipboard"
}