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
  )" 1 "$@" || return 0 

  NAMESPACE=$1
  SA_NAME=$2

  set -o pipefail
  kubectl -n $NAMESPACE get secrets $(kubectl -n $NAMESPACE get sa $SA_NAME -o json | jq -Mr '.secrets[].name') -o json | jq -Mr '.data.token' | base64 -D | pbcopy && echo "Token copied to clipboard"
}


kube_get_env_secret() {
  _show_help "$(cat <<-HELP
Echoes secret as env

Usage:
  kube_get_env_secret <namespace> <secret_name> <quote_values>

Example:
  kube_get_env_secret myapp env 1

HELP
  )" 1 "$@" || return 0 

  NAMESPACE=$1
  SECRET_NAME=$2

  # boolean eval, commands are swapped, looks at exit code. See https://stackoverflow.com/a/3810777
  if [[ $3 -eq "1" ]]; then
    kubectl -n $NAMESPACE get secrets $SECRET_NAME -o json |jq -r '.data | map_values(@base64d) | to_entries | .[] | .key + "=\"" + .value +"\""'
  else
    kubectl -n $NAMESPACE get secrets $SECRET_NAME -o json |jq -r '.data | map_values(@base64d) | to_entries | .[] | .key + "=" + .value'
  fi
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


kube_pod_images() {
  _show_help "$(cat <<-HELP
Show pod images in namespace or all namespaces

Example:
  kube_pod_images
  kube_pod_images kube-system
HELP
  )" 0 "$@" || return 0

  NAMESPACE=$1
  if [ -z "$NAMESPACE" ]; then
    NS_ARG="--all-namespaces"
  else
    NS_ARG="-n ${NAMESPACE}"
  fi

  kubectl get pods $NS_ARG -o jsonpath="{.items[*].spec.containers[*].image}" |tr -s '[[:space:]]' '\n' |sort |uniq -c
}

kube_all_images() {
  _show_help "$(cat <<-HELP
Show all images in namespace or all namespaces, as defined in various k8s objects

Example:
  kube_all_images ns1 ns2
HELP
  )" 1 "$@" || return 0

	local namespaces=("$@")

	for ns in $namespaces; do
	  echo "Namespace: $ns"
	  kubectl get deployments,statefulsets,daemonsets,cronjobs,jobs,replicasets -o json -n $ns | \
	  jq -r --arg ns "$ns" '.items[] |
	    .metadata.name as $name |
	    .kind as $kind |
	    (.spec.template.spec.initContainers[]? |
	      "\($ns): \($kind)/\($name) - spec.template.spec.initContainers[].image = \(.image)"),
	    (.spec.template.spec.containers[]? |
	      "\($ns): \($kind)/\($name) - spec.template.spec.containers[].image = \(.image)"),
	    (.spec.jobTemplate.spec.template.spec.initContainers[]? |
	      "\($ns): \($kind)/\($name) - spec.jobTemplate.spec.template.spec.initContainers[].image = \(.image)"),
	    (.spec.jobTemplate.spec.template.spec.containers[]? |
	      "\($ns): \($kind)/\($name) - spec.jobTemplate.spec.template.spec.containers[].image = \(.image)")'
	done
}

kube_all_pod_images() {
  _show_help "$(cat <<-HELP
List all pod container images in the given namespaces, including initContainers and their resolved imageIDs.

Example:
  kube_all_pod_images ns1 ns2
HELP
  )" 1 "$@" || return 0

  local namespaces=("$@")

  for ns in "${namespaces[@]}"; do
    echo "Namespace: $ns"
    kubectl get pods -n "$ns" -o json | jq -r --arg ns "$ns" '
      .items[] |
      .metadata.name as $pod |
      (
        .spec.initContainers // [] |
        map({
          type: "initContainer",
          name: .name,
          image: .image
        })
      ) as $initSpecs |
      (
        .spec.containers // [] |
        map({
          type: "container",
          name: .name,
          image: .image
        })
      ) as $containerSpecs |
      (
        .status.initContainerStatuses // [] |
        map({
          name: .name,
          imageID: .imageID
        })
      ) as $initStatuses |
      (
        .status.containerStatuses // [] |
        map({
          name: .name,
          imageID: .imageID
        })
      ) as $containerStatuses |

      ($initSpecs + $containerSpecs)[] |
      .type as $type |
      .name as $cname |
      .image as $image |
      (
        ($initStatuses + $containerStatuses)[] | select(.name == $cname) | .imageID
      ) as $imageID |
      "\($ns)\t\($pod)\t\($type)\t\($image)\t\($imageID)"
    ' | column -t -s $'\t'
    echo ""
  done
}


