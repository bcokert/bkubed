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
SERVICE_ACCOUNT_NAME="service_account"
ADMIN_NAME="admin"
DEVELOPER_NAME="developer"

function parse_args {
    GETOPT=getopt
    if [[ $(uname) == "Darwin" ]]; then
        GETOPT=/usr/local/opt/gnu-getopt/bin/getopt
        [[ ! -x $GETOPT ]] && (echo "you need gnu-getopt (brew)"; exit 1)
    fi
    local PARSED
    PARSED=$($GETOPT --options d:p:e:s: --name "$0" -- "$@")
    eval set -- "$PARSED"

    while true; do
        case "$1" in
            -d) ANSIBLE_DIR="$2";
            shift 2 ;;

            -p) ANSIBLE_VAULT_PASSWORD_FILE="$2";
            shift 2 ;;

            -e) ENV="$2";
            shift 2 ;;

            -s) KEYSIZE="$2";
            shift 2 ;;

            --) shift;
            break ;;
            *) error "arguments error";
            exit 3 ;;
        esac
    done

    # Required
    if [[ -z $ENV ]]; then
        error "environment" "must be set"
        usage
        exit 1
    fi

    if [[ -z $ANSIBLE_VAULT_PASSWORD_FILE ]]; then
        error "ansible-password-file" "must be set"
        usage
        exit 1
    fi

    # Defaults
    if [[ -z $ANSIBLE_DIR ]]; then
        ANSIBLE_DIR="./ansible"
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
  The certs are generated into the ansible provisioning roles, and the certs and keys
  are auto encrypted. Thus they are ready to provision to nodes.
  Also generated are the admin and developer account certs, which will need to
  be saved for future distribution.

  The CA chain is:
    $ROOT_CA_NAME -> $ETCD_CA_NAME -> $ETCD_PEER_NAME

    $ROOT_CA_NAME -> $KUBE_CA_NAME -> $ETCD_CLIENT_NAME
    $ROOT_CA_NAME -> $KUBE_CA_NAME -> $KUBE_API_NAME
    $ROOT_CA_NAME -> $KUBE_CA_NAME -> $KUBELET_NAME
    $ROOT_CA_NAME -> $KUBE_CA_NAME -> $SERVICE_ACCOUNT_NAME

    $ROOT_CA_NAME -> $KUBE_CA_NAME -> $ADMIN_NAME
    $ROOT_CA_NAME -> $KUBE_CA_NAME -> $DEVELOPER_NAME

Options:

  (environment)
  -e 'production'                    Environment to generate certs for. Determines
  (required)                         the CN (Common Name) of each cert. When deploying
                                     to different environemnts, the certs should always
                                     be regenerated

  (ansible-password-file)
  -p '~/ansible_password_file'       Path to the ansible password file for encrypting
  (required)                         of certs and keys.

  (ansible-directory)
  -d './ansible'                     Folder where ansible roles-local is found.
                                     Will overwrite any existing certs already in
                                     the roles of that folder.

  (keysize)
  -s 2048                            Size of the key in bits. Must be greater than
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
    info "Creating temporary certs dir. Do NOT commit this!"
    mkdir -p .generated_certs/${ENV} > /dev/null
    pushd .generated_certs/${ENV} > /dev/null

    info "Creating private Keys"
    set -x
    openssl genrsa -out ${ROOT_CA_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${ETCD_CA_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${KUBE_CA_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${ETCD_PEER_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${ETCD_CLIENT_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${KUBE_API_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${KUBELET_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${SERVICE_ACCOUNT_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${ADMIN_NAME}.key ${KEYSIZE}
    openssl genrsa -out ${DEVELOPER_NAME}.key ${KEYSIZE}
    set +x

    info "Creating Root CA cert"
    gen_self_signed_cert ${ROOT_CA_NAME}

    info "Creating Intermediate CA certs"
    gen_signed_cert ${ETCD_CA_NAME} ${ROOT_CA_NAME}
    gen_signed_cert ${KUBE_CA_NAME} ${ROOT_CA_NAME}

    info "Creating Node certs"
    gen_signed_cert ${ETCD_PEER_NAME} ${ETCD_CA_NAME}
    gen_signed_cert ${ETCD_CLIENT_NAME} ${KUBE_CA_NAME}
    gen_signed_cert ${KUBE_API_NAME} ${KUBE_CA_NAME}
    gen_signed_cert ${KUBELET_NAME} ${KUBE_CA_NAME}
    gen_signed_cert ${SERVICE_ACCOUNT_NAME} ${KUBE_CA_NAME}

    info "Creating User certs"
    gen_signed_cert ${ADMIN_NAME} ${KUBE_CA_NAME}
    gen_signed_cert ${DEVELOPER_NAME} ${KUBE_CA_NAME}

    info "Cleaning intermediate resources"
    rm -f *.srl
    rm -f *.csr

    popd > /dev/null

    info "Moving and encrypting certs for kube-controller"
    SSLROOT=${ANSIBLE_DIR}/roles-local/kube-controller/files/etc/ssl
    mkdir -p ${SSLROOT}/certs > /dev/null
    mkdir -p ${SSLROOT}/keys > /dev/null
    for CERT in ${ETCD_CLIENT_NAME} ${ETCD_PEER_NAME} ${KUBE_API_NAME} ${SERVICE_ACCOUNT_NAME}; do
      ansible-vault encrypt --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE} --output ${SSLROOT}/certs/${CERT}.crt.vault .generated_certs/${ENV}/${CERT}.crt
      ansible-vault encrypt --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE} --output ${SSLROOT}/keys/${CERT}.key.vault .generated_certs/${ENV}/${CERT}.key
    done

    info "Moving and encrypting certs for kube-tls-node"
    SSLROOT=${ANSIBLE_DIR}/roles-local/kube-tls-node/files/etc/ssl
    mkdir -p ${SSLROOT}/certs > /dev/null
    for CERT in ${ETCD_CA_NAME} ${KUBE_CA_NAME} ${ROOT_CA_NAME}; do
      ansible-vault encrypt --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE} --output ${SSLROOT}/certs/${CERT}.crt.vault .generated_certs/${ENV}/${CERT}.crt
    done

    info "Moving and encrypting certs for kubelet"
    SSLROOT=${ANSIBLE_DIR}/roles-local/kubelet/files/etc/ssl
    mkdir -p ${SSLROOT}/certs > /dev/null
    mkdir -p ${SSLROOT}/keys > /dev/null
    for CERT in ${KUBELET_NAME}; do
      ansible-vault encrypt --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE} --output ${SSLROOT}/certs/${CERT}.crt.vault .generated_certs/${ENV}/${CERT}.crt
      ansible-vault encrypt --vault-password-file ${ANSIBLE_VAULT_PASSWORD_FILE} --output ${SSLROOT}/keys/${CERT}.key.vault .generated_certs/${ENV}/${CERT}.key
    done
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
    info "Encrypted output will be created in ./$ANSIBLE_DIR/"
    gen_certs
    exit $?
}

main "$@"
