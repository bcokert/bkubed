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
            *) echo "arguments error";
            exit 3 ;;
        esac
    done

    # Required
    if [[ -z $ENV ]]; then
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
    #TODO: validate keysize
}

function usage {
    cat <<- HERE
		usage: $(basename "$0")
          OPTIONS:
		  -d|--certs-dir PATH                folder to write new certs to. Defaults to "generated_certs"
		  -e|--env (dev|staging|production)  environment to generate certs for to (required)
		  -s|--keysize NUMBITS               size of the key in bits. Defaults to 2048

          FLAGS:
		HERE
}

function gen_certs {
    mkdir -p ${CERTS_DIR}/${ENV}
    pushd ${CERTS_DIR}/${ENV}

    set -x

    # Private Keys
    openssl genrsa -out ${ROOT_CA_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${ETCD_CA_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${KUBE_CA_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${ETCD_PEER_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${ETCD_CLIENT_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${KUBE_API_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${KUBELET_NAME}.key ${KEYSIZE}

    # Root CA cert
    gen_self_signed_cert ${ROOT_CA_NAME}

    # Intermediate CA certs
    gen_signed_cert ${ETCD_CA_NAME} ${ROOT_CA_NAME}
    gen_signed_cert ${KUBE_CA_NAME} ${ROOT_CA_NAME}

    # Node certs
    gen_signed_cert ${ETCD_PEER_NAME} ${ETCD_CA_NAME}
    gen_signed_cert ${ETCD_CLIENT_NAME} ${KUBE_CA_NAME}
    gen_signed_cert ${KUBE_API_NAME} ${KUBE_CA_NAME}
    gen_signed_cert ${KUBELET_NAME} ${KUBE_CA_NAME}

    # Cleanup
    rm -f *.srl
    rm -f *.csr

    set +x
    popd
}

function gen_self_signed_cert {
    # $1 = cert to sign
    openssl req -x509 -new -key ${1}.key -subj "/CN=bkubed ${ENV} ${1}" -days 100000 -out ${1}.crt
}

function gen_signed_cert {
    # $1 = cert to sign, $2 = signer
    openssl req -new -key ${1}.key -subj "/CN= ${ENV} ${1}" -out ${1}.csr
    openssl x509 -req -in ${1}.csr -CA ${2}.crt -CAkey ${2}.key -CAcreateserial -days 100000 -out ${1}.crt
}

function main {
    parse_args "$@"
    gen_certs
    exit $?
}

main "$@"
