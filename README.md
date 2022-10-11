

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
```sh
export https_proxy=http://approxy.xx.com:80
export http_proxy=http://approxy.xx.com:80
cd /Users/joeqiao/Documents/LocalHub/cka/local-k8s-cks
vagrant up
```
This step creates 2 vms, configure them to run k8s.

## init master

login and prepare
```sh
vagrant ssh master
sudo su -
echo "192.168.50.4" master.k8s.local >> /etc/hosts
echo "192.168.50.5" node.k8s.local >> /etc/hosts
```
install container runtime following https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker
```sh
apt-get update
apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-cache madison docker-ce
apt-get install docker-ce=5:19.03.15~3-0~ubuntu-focal docker-ce-cli=5:19.03.15~3-0~ubuntu-focal containerd.io docker-compose-plugin
service docker start
docker run hello-world

```
install kube* following https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl


`vagrant up` does this, but after the master is up, you should found below
line in /tmp/kubeadm.output

```
Then you can join any number of worker nodes by running the following on each
as root:

kubeadm join 10.0.2.15:6443 --token rtsj9q.n6co2ozslz7a4mrt \
    --discovery-token-ca-cert-hash

```

## init node
quit master vm
```
vagrant ssh node
sudo su - 
THEN_RUN_THE_JOIN_COMMAND
```
