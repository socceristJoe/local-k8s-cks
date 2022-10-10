# vagrant kubernetes bootstrap
This repo bootstrap 2 ubuntu VMs which is used to create K8s.


# pre-requirements
1. install virtualbox
brew install --cask virtualbox
for big sur, better download newest version from site
2. install vagrant
brew install --cask vagrant
 
# usage

## create VMs
```
export https_proxy=http://approxy.pg.com:80
export http_proxy=http://approxy.pg.com:80
cd /Users/joeqiao/Documents/LocalHub/cka/local-k8s
vagrant up
```
This step creates 2 vms, configure them to run k8s.

## init master

`vagrant up` does this, but after the master is up, you should found below
line in /tmp/kubeadm.output

```
Then you can join any number of worker nodes by running the following on each
as root:

kubeadm join 10.0.2.15:6443 --token rtsj9q.n6co2ozslz7a4mrt \
    --discovery-token-ca-cert-hash
    sha256:689b568918dde8dad70f68db0e86be407164cbab3bf77a390f633bf05c27e747
```

## init node
quit master vm
```
vagrant ssh node
sudo su - 
THEN_RUN_THE_JOIN_COMMAND
```
