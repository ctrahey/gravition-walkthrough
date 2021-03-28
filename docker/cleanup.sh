#! /usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
pushd $DIR
kubectl delete statefulset dind-arm
kubectl delete service docker-arm
kubectl delete cm docker-hostname
docker buildx rm mixed-arch
docker context rm graviton
rm ./certs/*
popd
