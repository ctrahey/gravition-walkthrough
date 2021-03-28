# Graviton + EKS walkthrough
A set of scripts and assets to:

1. Create an EKS cluster with a mix of Graviton2 and Intel X86 instances.
1. Setup Docker to build a "manifest" image that can be run on either architecture, building for ARM directly on a Graviton2 instance
1. Deploy a sample app that reports which CPU architecture it's running on

## 1. Create EKS cluster
Here we use eksctl to create a cluster with 2 managed node groups, one with Graviton2-based c6g instances, and the other with Intel Xeon-based t3 instances. 
```
eksctl create -f cluster.yaml
```


## Docker
To run a single "Deployment" that spans X86 and ARM instances, we need to create a "Manifest" image. These images are actually just text files that "point to" a seperate image per CPU architecture. Docker buildx is a tool that can take care of building both images plus the manifest. Even better: We can setup a remote docker context to build the ARM image directly on a Graviton2 instance in AWS, while the X86 image is build locally on our developer machine. 

Since we already have an EKS cluster with Graviton2 instances available, we can just deploy a Docker container to this cluster with a nodeSelector that 'pins' the pods to the Graviton instances. I have included a script `docker/setup.sh` which performs the following steps to set this up:

1. Create a LoadBalancer Service
1. Extract the hostname from the Service
1. Add this hostname to a ConfigMap (Docker needs it to create appropriate TLS certificates)
1. Deploy docker to the cluster
1. Wait for LoadBalancer to be ready (implies certificates are ready, docker is accepting connections)
1. Download Client certificates that Docker generated
1. Use the Client certificates to setup a remote docker context, which will build on the Graviton2 instance
1. Create a buildx builder that will send ARM builds to the remote context, and build X86 images locally.

```
Note: If you have a new M1 mac (or you're on a Raspberry Pi or any other ARM machine), 
you will want to flip the logic in this entire setup: 
Build for ARM locally, and use a remote context to build for X86.
The overall approach used here should work. Change nodeSelector and various names, etc...
```

## Sample App
Once the docker context and buildx builder are configured, you can build the included sample app like this:
Note: replace [ctrahey/hello-arch] with an image repository that you have push access to (and that your cluster has pull access from).
I am using ctrahey/hello-arch, which I setup for this walkthrough. Feel free to use this image, though you will not be able to push to it.
```
docker buildx build --builder mixed-arch --platform linux/amd64,linux/arm64 -t ctrahey/hello-arch:latest ./app"

```
With the image built and pushed to a repository, you can deploy it into our EKS cluster. Note that if you follow this walkthrough and push to your own repository, you'll need to change the image field in the deployment.yaml. I have configured the deployment to create 8 replicas, enough to be nearly certain that there will be replicas on both ARM and X86 instances. 
```
kubectl apply -f deployment/deployment.yaml
```
This file also creates another Load Balancer service. Note that it can take a couple minutes for DNS propogation (in my testing about 1-5 minutes).
Get your load balancer URL with `kubectl get svc sample-app` and load it in a browser. Refresh a few times to see the architecture switches back and forth. 

## Congrats! 
### You have a mixed-architecture EKS cluster with a single deployment happily serving traffic from either instance type!
