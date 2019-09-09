# Copies kubernetes dashboard bearer token to clipboard
kube_get_admin_token() {
  _show_help "$(cat <<-HELP
Copies kube-system admin-user token to clipboard.
HELP
  )" 0 "$@" || return 0 

  set -o pipefail
  kubectl -n kube-system get secrets -o json|jq '.items[0].data.token'|tr -d '"'|base64 -D| pbcopy && echo "Token copied to clipboard"
}


kube_get_sa_token() {
  _show_help "$(cat <<-HELP
Copies token for service account in given namespace to clipboard.

Usage:
  kube_get_sa_token <namespace> <sa_name>

HELP
  )" 0 "$@" || return 0 

  NAMESPACE=$1
  SA_NAME=$2

  set -o pipefail
  kubectl -n $NAMESPACE get secrets $(kubectl -n $NAMESPACE get sa $SA_NAME -o json | jq -Mr '.secrets[].name') -o json | jq -Mr '.data.token' | base64 -D | pbcopy && echo "Token copied to clipboard"
}



kube_port_forward() {
  _show_help "$(cat <<-HELP
Sets up port forwarding to a pod, using labels as selector
     
Usage:
  kube_port_forward <namespace> <selector> <port[:port]> 

Example:
  kube_port_forward prometheus app=prometheus,component=server 9090:9090 
HELP
  )" 1 "$@" || return 0	

  NAMESPACE=$1
  SELECTOR=$2
  PORTS=$3
  
  set -x
  kubectl port-forward $(kubectl get pod --selector $SELECTOR -o jsonpath={.items..metadata.name} -n $NAMESPACE) -n $NAMESPACE $PORTS
  set +x
}
