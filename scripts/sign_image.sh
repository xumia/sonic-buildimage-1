#!/bin/bash -ex

#  Copyright (C) 2014 Curt Brune <curt@cumulusnetworks.com>
#
#  SPDX-License-Identifier:     GPL-2.0

IMAGE=""
SIGNING_KEY=""
SIGNING_CERT=""
CA_CERT=""
TARGET_PATH=""
TMP_CERT_PATH="/tmp/cert"
CERT_PATH=""

usage()
{
    echo "Usage:  $0 -i <image_path> [-c <cert_path>] [-t <cert_target_path>]"
    exit 1
}

generate_singing_key()
{
    SINGING_CSR="${TMP_CERT_PATH}/signing.csr"
    CA_KEY="${TMP_CERT_PATH}/ca.key"
    mkdir -p "${TMP_CERT_PATH}"

    # Generate the CA key and certificate
    openssl genrsa -out $CA_KEY 4096
    openssl req -x509 -new -nodes -key $CA_KEY -sha256 -days 3650 -subj "/C=US/ST=Seattle/L=Redmond/O=SONiC/CN=www.sonic.com" -out $CA_CERT

    # Generate the signing key, certificate request and certificate
    openssl genrsa -out $SIGNING_KEY 4096
    openssl req -new -key $SIGNING_KEY -subj "/C=US/ST=Seattle/L=Redmond/O=SONiC/CN=www.sonic.com" -out $SINGING_CSR
    openssl x509 -req -in $SINGING_CSR -CA $CA_CERT -CAkey $CA_KEY -CAcreateserial -out $SIGNING_CERT -days 1825 -sha256

    # Remove no use files
    rm -f $CA_CEY
    rm -f $SIGNING_CSR
}

while getopts ":i:c:t:" opt; do
    case $opt in
        i)
            IMAGE=$OPTARG
            ;;
        c)
            CERT_PATH=$OPTARG
            ;;
        t)
            TARGET_PATH=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done

[ ! -z $CERT_PATH ] && TMP_CERT_PATH=$CERT_PATH
SIGNING_KEY="${TMP_CERT_PATH}/signing.key"
SIGNING_CERT="${TMP_CERT_PATH}/signing.crt"
CA_CERT="${TMP_CERT_PATH}/ca.crt"

# Generate the self signed cert if not provided by input
[ -z $CERT_PATH ] && generate_singing_key

[ ! -f $SIGNING_KEY ] && echo "$SIGNING_KEY not exist" && exit 1
[ ! -f $SIGNING_CERT ] && echo "$SIGNING_CERT not exist" && exit 1
[ ! -f $CA_CERT ] && echo "$CA_CERT not exist" && exit 1

# Prepare the image
swi-signature prepare $IMAGE

# Sign the image
swi-signature sign $IMAGE $SIGNING_CERT $CA_CERT --key $SIGNING_KEY

# Copy the CA cert target folder
[ ! -z $TARGET_PATH ] && cp $CA_CERT $TARGET_PATH

exit 0
