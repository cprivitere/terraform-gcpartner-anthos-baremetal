#!/bin/bash 
KSA_NAME=gke-login
SECRET_NAME=${KSA_NAME}-token


kubectl apply -f - << __EOF__
apiVersion: v1
kind: Secret
metadata:
  name: "${SECRET_NAME}"
  annotations:
    kubernetes.io/service-account.name: "${KSA_NAME}"
type: kubernetes.io/service-account-token
__EOF__

until [[ $(kubectl get -o=jsonpath="{.data.token}" "secret/${SECRET_NAME}") ]]; do
  echo "waiting for token..." >&2;
  sleep 1;
done

kubectl get secret ${SECRET_NAME} -o jsonpath='{$.data.token}' | base64 --decode