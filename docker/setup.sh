#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
pushd $DIR
echo "Applying DIND Service"
kubectl apply -f ./dind-service.yaml
LB_HOST=$(kubectl get svc docker-arm -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Waiting for LB hostname to be populated... (timeout 30s)"
date
i=0
while [ -z "$LB_HOST" ] && ((i < 15))
do
  ((i=i+1))
  sleep 2
  LB_HOST=$(kubectl get svc docker-arm -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
done
date
if [ -z "$LB_HOST" ]
then
  echo "#### ERROR ####"
  echo "#### Exiting: No hostname discovered after 30s."
  echo "#### It should be safe to re-run this script when the LB is setup."
  echo "###############"
  exit 1
fi

echo "Hostname discovered: $LB_HOST"
# Adding DNS: prefix for the Subject-Alt-Name format:
DOCKER_SAN=DNS:$LB_HOST
kubectl create configmap docker-hostname --from-literal=hostname=$DOCKER_SAN
# Create Deployment (which refers to that configmap)
kubectl apply -f dind.yaml

popd