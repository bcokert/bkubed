#!/usr/bin/env bash
set -e

ROOT_DIR=$(dirname "${BASH_SOURCE[0]}")
BASE_DIR=$(dirname "$(cd "${ROOT_DIR}" && pwd)")

ROOT_CA_NAME="root_ca"
ETCD_CA_NAME="etcd_ca"
KUBE_CA_NAME="kube_ca"

ETCD_PEER_NAME="etcd_peer"
ETCD_CLIENT_NAME="etcd_client"
KUBE_API_NAME="kube_api"
KUBELET_NAME="kubelet"

function parse_args {
    GETOPT=getopt
    if [[ $(uname) == "Darwin" ]]; then
        GETOPT=/usr/local/opt/gnu-getopt/bin/getopt
        [[ ! -x $GETOPT ]] && (echo "you need gnu-getopt (brew)"; exit 1)
    fi
    local PARSED
    PARSED=$($GETOPT --options d::e:s:: --longoptions certs-dir::env:keysize::dry --name "$0" -- "$@")
    eval set -- "$PARSED"

    while true; do
        case "$1" in
            -d | --certs-dir) CERTS_DIR="$2";
            shift 2 ;;

            -e | --env) ENV="$2";
            shift 2 ;;

            -s | --keysize) KEYSIZE="$2";
            shift 2 ;;

            --) shift;
            break ;;
            *) error "arguments error";
            exit 3 ;;
        esac
    done

    # Required
    if [[ -z $ENV ]]; then
        error "env" "must be set"
        usage
        exit 1
    fi

    # Defaults
    if [[ -z $CERTS_DIR ]]; then
        CERTS_DIR="generated_certs"
    fi

    if [[ -z $KEYSIZE ]]; then
        KEYSIZE=2048
    fi

    # Validation
    re='^[1-9][0-9]{3}$'
    if ! [[ $KEYSIZE =~ $re ]] ; then
        error "keysize" "must be an integer >= 1000" >&2
        usage
        exit 1
    fi
}

function usage {
    MSG="
Usage: $(basename "$0" [options])

  Generates new certs for each node-type.

  Etcd certs are always generated, even if etcd will not have its own physical node.
  These certs need to be provisioned to the nodes after generating, or saved
  somewhere for future use.

  The CA chain is:
    $ROOT_CA_NAME -> $ETCD_CA_NAME -> $ETCD_PEER_NAME

    $ROOT_CA_NAME -> $KUBE_CA_NAME -> $ETCD_CLIENT_NAME
    $ROOT_CA_NAME -> $KUBE_CA_NAME -> $KUBE_API_NAME
    $ROOT_CA_NAME -> $KUBE_CA_NAME -> $KUBELET_NAME

Options:

  -e|--env 'production'              Environment to generate certs for. Determines
  (required)                         the CN (Common Name) of each cert, as well
                                     as the output subfolder.

  -d|--certs-dir generated_certs     Folder to write new certs to. Defaults to
                                     'generated_certs'. Will overwrite any existing
                                     certs already in that folder. Certs are added
                                     to subfolders within the certs-dir, one per
                                     environment.

  -s|--keysize 2048                  Size of the key in bits. Must be greater than
                                     or equal to 1000.
"

    echo -e "\x1B[33m$MSG\x1B[0m"
}

function error {
    echo -e "\n\x1B[31mError ($1): $2\x1b[0m" >&2
}

function info {
    echo -e "\n\x1B[1m$1\x1b[0m"
}

function gen_certs {
    mkdir -p ${CERTS_DIR}/${ENV} > /dev/null
    pushd ${CERTS_DIR}/${ENV} > /dev/null

    info "Creating private Keys"
    set -x
    openssl genrsa -out ${ROOT_CA_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${ETCD_CA_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${KUBE_CA_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${ETCD_PEER_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${ETCD_CLIENT_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${KUBE_API_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${KUBELET_NAME}.key ${KEYSIZE}
    set +x

    info "Creating Root CA cert"
    gen_self_signed_cert ${ROOT_CA_NAME}

    info "Creating Intermediate CA certs"
    gen_signed_cert ${ETCD_CA_NAME} ${ROOT_CA_NAME}
    gen_signed_cert ${KUBE_CA_NAME} ${ROOT_CA_NAME}

    info "Creating Node CA certs"
    gen_signed_cert ${ETCD_PEER_NAME} ${ETCD_CA_NAME}
    gen_signed_cert ${ETCD_CLIENT_NAME} ${KUBE_CA_NAME}
    gen_signed_cert ${KUBE_API_NAME} ${KUBE_CA_NAME}
    gen_signed_cert ${KUBELET_NAME} ${KUBE_CA_NAME}

    info "Cleaning intermediate resources"
    rm -f *.srl
    rm -f *.csr

    popd > /dev/null
}

function gen_self_signed_cert {
    # $1 = cert to sign
    (set -x; openssl req -x509 -new -key ${1}.key -subj "/CN=bkubed ${ENV} ${1}" -days 100000 -out ${1}.crt)
}

function gen_signed_cert {
    # $1 = cert to sign, $2 = signer
    (set -x; openssl req -new -key ${1}.key -subj "/CN= ${ENV} ${1}" -out ${1}.csr)
    (set -x; openssl x509 -req -in ${1}.csr -CA ${2}.crt -CAkey ${2}.key -CAcreateserial -days 100000 -out ${1}.crt)
}

function main {
    parse_args "$@"

    info "Generating certificate chain for '$ENV', using $KEYSIZE bit keys"
    info "Output will be created or updated in ./$CERTS_DIR/$ENV/"
    gen_certs
    exit $?
}

main "$@"
