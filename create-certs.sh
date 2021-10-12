#!/bin/sh

KEY_FILE=cert.key
CERT_FILE=cert.crt
CERT_NAME=rmt-cert
HOST=$1


openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${KEY_FILE} -out ${CERT_FILE} -subj "/CN=${HOST}/O=${HOST}"
kubectl create secret tls ${CERT_NAME} --key ${KEY_FILE} --cert ${CERT_FILE}

kubectl delete secret ${CERT_NAME}
kubectl create secret tls ${CERT_NAME} --key ${KEY_FILE} --cert ${CERT_FILE}
#kubectl delete configmap rmt-ca-configmap
#kubectl create configmap rmt-ca-configmap --from-file=${CERTDIR}/rmt-ca.crt
