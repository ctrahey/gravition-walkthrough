# Graviton + EKS walkthrough
This repo holds simplified assets that demonstrate the use of Graviton 2 on EKS.


## Docker Context

1. Create Service
1. Extract hostname
1. create certs with appropriate hostname
1. create secrets from certs
1. deploy (with mounted secrets)
1. create docker context



LB_HOST=$(kubectl get svc docker-arm -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
kubectl create configmap docker-hostname --from-literal=hostname=DNS:$LB_HOST


docker context create graviton --description "Remote context on AWS Graviton 2, use for ARM image building" --docker "host=tcp://a1c80ba85758144f3ad0da3804cc79f9-511706651.us-west-2.elb.amazonaws.com:2376,ca=$(pwd)/certs/ca.pem,cert=$(pwd)/certs/cert.pem,key=$(pwd)/certs/key.pem"

docker buildx create --use --name local default
docker buildx build --platform linux/amd64,linux/arm64 -t whereabouts:multi .
docker buildx create --name remote default
docker buildx create --append  --name remote graviton
docker buildx build --builder remote --platform linux/amd64,linux/arm64 -t whereabouts:multi-remote .

### Notes
https://github.com/containerd/containerd/issues/4837
https://github.com/docker-library/docker/blob/094faa88f437cafef7aeb0cc36e75b59046cc4b9/20.10/dind/dockerd-entrypoint.sh#L18
https://github.com/ansible/ansible/issues/35550#issuecomment-361963626

#### Timings
With "Cryptography" package:
- Qemu (Docker has: 5 CPUs, 10GB RAM): 
- Remote Graviton (amd64 still local): 5m37s