#!/bin/sh

KEY_FILE=rmt-cert.key
CERT_FILE=rmt-cert.crt
CERT_NAME=rmt-cert
HOST=$1

CMD="openssl req -nodes -newkey rsa:2048 -keyout ${KEY_FILE} -out ${CERT_FILE} -subj \"/CN=${HOST}/O=${HOST}\" -addext \"subjectAltName = DNS:${HOST}\""
echo $CMD
openssl req -x509 -nodes -newkey rsa:2048 -keyout ${KEY_FILE} -out ${CERT_FILE} -subj "/CN=${HOST}/O=${HOST}" -addext "subjectAltName = DNS:${HOST}"
#
kubectl delete secret ${CERT_NAME}
kubectl create secret tls ${CERT_NAME} --key ${KEY_FILE} --cert ${CERT_FILE}
#kubectl delete configmap rmt-ca-configmap
#kubectl create configmap rmt-ca-configmap --from-file=${CERTDIR}/rmt-ca.crt
