#!/bin/bash

set -euo pipefail

if [[ $USER != "root" ]]; then
    >&2 echo "This script must be run with super-user privileges."
    exit 1
fi

print_usage() {
    echo "Starts k3s and installs Gitpod with a GitLab instance as OAuth provider."
    echo ""
    echo "Usage: $0 [<OPTIONS>] <Gitpod host> <GitLab host> <OAuth client ID> <OAuth client secret> [<ADDITIONAL K3S ARGUMENTS>]"
    echo "  -h                         prints this message"
    echo "  -c <HTTPS certs folder>    HTTPS cert folder, default: /etc/certs"
    echo "  -k <k3s bin>               k3s binary, default: k3s"
    echo "  -y <yaml files folder>     folder with the YAML template files, default: ."
    echo "  -s <URI scheme>            URI scheme, https or http, default: https"
    echo ""
    echo "Example:"
    echo "$0 -c ~/certs -k /usr/bin/k3s -y ~/gitpod-k3s-helm-installer gitpod.example.com gitlab.example.com 2ce8bfb95d9a1e0ed305427f35e10a6bdd1eef090b1890c68e5f8370782d05ee a5447d23643f7e71353d9fc3ad1c15464c983c47f6eb2e80dd37de28152de05e --bind-address 127.0.0.1"
}

CERTS_DIR=/etc/ssl
K3S_BIN=k3s
YAML_FILES_DIR=.
URI_SCHEME=https

while getopts 'c:k:y:s:h' flag; do
  case "${flag}" in
    c) CERTS_DIR="$OPTARG" ;;
    k) K3S_BIN="$OPTARG" ;;
    y) YAML_FILES_DIR="$OPTARG" ;;
    s) URI_SCHEME="$OPTARG" ;;
    h) print_usage
       exit 0 ;;
    *) >&2 print_usage
       exit 1 ;;
  esac
done

shift $((OPTIND -1))

if [[ $# -lt 4 ]]; then
    >&2 print_usage
    exit 1
fi

K3S_MANIFEST_DIR=/var/lib/rancher/k3s/server/manifests
K3S_YAML_FILE=/etc/rancher/k3s/k3s.yaml

CHAIN_CERT=$CERTS_DIR/chain.pem
DHPARAMS_CERT=$CERTS_DIR/dhparams.pem
FULLCHAIN_CERT=$CERTS_DIR/fullchain.pem
PRIVKEY_CERT=$CERTS_DIR/privkey.pem

GITPODHOST=$1
GITLABHOST=$2
OAUTH_CLIENTID=$3
OAUTH_CLIENTSECRET=$4

shift 4

kubeconfig_replaceip() {
    while [ ! -f $K3S_YAML_FILE ]; do sleep 1; done
    HOSTIP=$(hostname)
    sed "s+127.0.0.1+$HOSTIP+g" "$K3S_YAML_FILE" > "${K3S_YAML_FILE%.yaml}_ext.yaml"
}
kubeconfig_replaceip &

add_deployment() {
    while [ ! -d $K3S_MANIFEST_DIR/ ]; do sleep 1; done

    CHAIN=$(base64 --wrap=0 < "$CHAIN_CERT")
    DHPARAMS=$(base64 --wrap=0 < "$DHPARAMS_CERT")
    FULLCHAIN=$(base64 --wrap=0 < "$FULLCHAIN_CERT")
    PRIVKEY=$(base64 --wrap=0 < "$PRIVKEY_CERT")
    export CHAIN DHPARAMS FULLCHAIN PRIVKEY
    envsubst < "$YAML_FILES_DIR/proxy-config-certificates.yaml" > $K3S_MANIFEST_DIR/proxy-config-certificates.yaml

    export GITPODHOST GITLABHOST OAUTH_CLIENTID OAUTH_CLIENTSECRET URI_SCHEME
    envsubst < "$YAML_FILES_DIR/gitpod-helm-installer.yaml" > $K3S_MANIFEST_DIR/gitpod-helm-installer.yaml
}
add_deployment &

set -x
"$K3S_BIN" server --disable traefik "$@"
set +x

if [[ -n "$(jobs -p)" ]]; then
    jobs -p | xargs kill
fi
