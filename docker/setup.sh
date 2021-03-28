#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
pushd $DIR


echo "Applying DIND Service"
kubectl apply -f ./dind-service.yaml


echo -n "Waiting for LB hostname to be populated... (expect ~5 seconds)"
LB_HOST=$(kubectl get svc docker-arm -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
i=0
while [ -z "$LB_HOST" ] && ((i < 15))
do
  echo -n "."
  ((i=i+1))
  sleep 2
  LB_HOST=$(kubectl get svc docker-arm -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
done
if [ -z "$LB_HOST" ]
then
  echo "#### ERROR ####"
  echo "#### Exiting: No hostname discovered after 30s."
  echo "#### It should be safe to re-run this script when the LB is setup."
  echo "###############"
  exit 1
fi
echo " done."

# Adding DNS: prefix for the Subject-Alt-Name format:
# see https://github.com/ansible/ansible/issues/35550#issuecomment-361963626
DOCKER_SAN=DNS:$LB_HOST
echo "Creating configmap with Subject Alt Name: $DOCKER_SAN"
kubectl delete configmap docker-hostname 2>/dev/null
kubectl create configmap docker-hostname --from-literal=hostname=$DOCKER_SAN
echo "Creating Deployment."
kubectl apply -f dind.yaml


echo -n "Waiting for Load Balancer to be ready (expect 1~2 minutes)"
until nc -z $LB_HOST 2376 2>/dev/null;
do
  echo -n "."
  sleep 5
done
echo " ready."


echo "downloading client certificates to authenticate with Docker..."
rm -rf ./certs/* 2>/dev/null
kubectl cp dind-arm-0:/certs/client ./certs

echo "Setting up docker contexts and buildx builder"
# Note: If you have a new M1 mac (or you're on a Raspberry Pi or any other ARM machine), 
# you will want to flip the logic in this entire setup: 
# Build for ARM locally, and use a remote context to build for X86.
# The overall approach used here should work. Change nodeSelector and various names, etc...
docker context rm graviton 2>/dev/null
docker context create graviton \
  --description "Remote context on AWS Graviton 2, use for ARM image building" \
  --docker "host=tcp://$LB_HOST:2376,ca=$(pwd)/certs/ca.pem,cert=$(pwd)/certs/cert.pem,key=$(pwd)/certs/key.pem"
docker buildx rm mixed-arch 2>/dev/null
docker buildx create --name mixed-arch --platform linux/amd64 default
docker buildx create --append  --name mixed-arch --platform linux/arm64 graviton

echo "#############"
echo "##  DONE!  ##"
echo "#############"
echo "To build, run the following:"
echo "docker buildx build --push --builder mixed-arch --platform linux/amd64,linux/arm64 -t ctrahey/hello-arch:latest ./app"

popd
