#!/bin/bash
KSA_NAME=gke-login
kubectl create serviceaccount ${KSA_NAME}
kubectl create clusterrolebinding gke-login-view --clusterrole view --serviceaccount default:${KSA_NAME}
kubectl create clusterrolebinding gke-login-cloud-console-reader --clusterrole cloud-console-reader --serviceaccount default:${KSA_NAME}
