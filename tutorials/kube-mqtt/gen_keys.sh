#!/bin/bash -x
# This was mostly havested from:
# http://www.steves-internet-guide.com/mosquitto-tls/

SERVER_IP=mqtt-bridge.bascornd.app
CERTS_DIR=base/certs/

# Clear old ones
rm -rf $CERTS_DIR/*
mkdir -p $CERTS_DIR

# Create openssl config file
cat << EOF > openssl.conf
[req]
default_bits=2048
encrypt_key=no
default_md=sha256
distinguished_name=req_subj
prompt=no
# req_extensions=req_ext
# x509_extensions=v3_req
# [req_ext]
# subjectAltName = @alt_names
# [v3_req]
# subjectAltName = @alt_names
# [alt_names]
# IP.1=$SERVER_IP
[req_subj]
commonName="$SERVER_IP"
emailAddress="none@none.org"
countryName=US
stateOrProvinceName=Wisconsin
localityName=Milwaukee
organizationName="BnS"
organizationalUnitName="Concept Team"
EOF

# Create key pair for CA
openssl genrsa -des3 -out $CERTS_DIR/ca.key 2048

# Certificate for CA using CA key
sed -i "s/organizationalUnitName=.*/organizationalUnitName=\"Concept Team CA Cert\"/" openssl.conf
openssl req -new -config openssl.conf -x509 -days 1826 -key $CERTS_DIR/ca.key -out $CERTS_DIR/ca.crt

# server key pair that will be used by the MQTT broker
openssl genrsa -out $CERTS_DIR/server.key 2048

# Create a certificate request csr
# Common name is the IP or FQDN of the MQTT broker
sed -i "s/organizationalUnitName=.*/organizationalUnitName=\"Concept Team Server Key\"/" openssl.conf
openssl req -new -config openssl.conf -out $CERTS_DIR/server.csr -key $CERTS_DIR/server.key

# use CA to verify and sign the server certificate, this creates the server.crt
openssl x509 -req -in $CERTS_DIR/server.csr -CA $CERTS_DIR/ca.crt -CAkey $CERTS_DIR/ca.key -CAcreateserial -out $CERTS_DIR/server.crt -days 360

rm openssl.conf
# You should now have the following 3 needed files:
# ca.cert server.crt server.key 

