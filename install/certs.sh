#!/bin/bash

# Define the path for the configuration and certificate files
BASE_DIR="files/openvpn/certs"
CONFIG_FILE="files/openvpn/openssl.cnf"
CA_KEY_FILE="$BASE_DIR/ca-key.pem"
CA_CERT_FILE="$BASE_DIR/ca-cert.pem"
GOAD_KEY_FILE="$BASE_DIR/goad-key.pem"
GOAD_CSR_FILE="$BASE_DIR/goad-csr.pem"
GOAD_CERT_FILE="$BASE_DIR/goad-cert.pem"
USER_KEY_FILE="$BASE_DIR/user-key.pem"
USER_CSR_FILE="$BASE_DIR/user-csr.pem"
USER_CERT_FILE="$BASE_DIR/user-cert.pem"
GOAD_CONF="goad.conf"

# Create the OpenSSL configuration file
cat > $CONFIG_FILE << EOF
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt             = no

[ req_distinguished_name ]
C  = US
ST = New York
L  = New York
O  = $(awk -F= '/CERT_ORG/ {print $2}' $GOAD_CONF)
OU = $(awk -F= '/CERT_OU/ {print $2}' $GOAD_CONF)
CN = $(awk -F= '/CERT_CN=PENTEST/ {print $2}' $GOAD_CONF)
emailAddress = admin@goad.lab

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = vpn.goad.lab
DNS.2 = www.vpn.goad.lab

[ v3_ca ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer:always
basicConstraints       = critical, CA:true
keyUsage               = critical, cRLSign, keyCertSign

[ v3_req ]
basicConstraints       = CA:FALSE
keyUsage               = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage       = serverAuth, clientAuth
subjectAltName         = @alt_names
EOF

# Function to generate key and certificate
generate_cert() {
    local key_file=$1
    local csr_file=$2
    local cert_file=$3
    local ext=$4
    openssl genpkey -algorithm RSA -out $key_file -pkeyopt rsa_keygen_bits:2048
    openssl req -new -key $key_file -out $csr_file -config $CONFIG_FILE -extensions $ext
    openssl x509 -req -days 365 -in $csr_file -CA $CA_CERT_FILE -CAkey $CA_KEY_FILE -CAcreateserial -out $cert_file -sha256 -extfile $CONFIG_FILE -extensions $ext
}

# Generate CA key and certificate
openssl genpkey -algorithm RSA -out $CA_KEY_FILE -pkeyopt rsa_keygen_bits:2048
openssl req -new -key $CA_KEY_FILE -out ${CA_CERT_FILE%.pem}.csr -config $CONFIG_FILE -extensions v3_ca
openssl x509 -req -days 3650 -in ${CA_CERT_FILE%.pem}.csr -signkey $CA_KEY_FILE -out $CA_CERT_FILE -extensions v3_ca -extfile $CONFIG_FILE

# Generate server and user keys and certificates
generate_cert $GOAD_KEY_FILE $GOAD_CSR_FILE $GOAD_CERT_FILE v3_req
generate_cert $USER_KEY_FILE $USER_CSR_FILE $USER_CERT_FILE v3_req

echo "CA key and certificate have been generated:"
echo "Private Key: $CA_KEY_FILE"
echo "Certificate: $CA_CERT_FILE"
