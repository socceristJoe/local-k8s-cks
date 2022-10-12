

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

### prepare host
#### login
```sh
vagrant ssh master
sudo su -
echo "192.168.50.4" master.k8s.local >> /etc/hosts
echo "192.168.50.5" node.k8s.local >> /etc/hosts
```
#### install company certificate if any
http://www.noobyard.com/article/p-bqevkrkr-mx.html
```sh
echo -n | openssl s_client -showcerts -connect production.cloudflare.docker.com:443 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /usr/share/ca-certificates/pg-ca/cloudfront.crt
cat >>/etc/ca-certificates.conf<<EOF
pg-ca/cloudfront.crt
EOF
update-ca-certificates --fresh
```
### install prerequesites
#### install container runtime following https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker
##### install docker engine
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
##### install cri-dockerd 
https://github.com/Mirantis/cri-dockerd
```sh
cp -r /vagrant/files/cri-dockerd/ .
mkdir cri-dockerd/bin && cd cri-dockerd/bin
VERSION=$((git describe --abbrev=0 --tags | sed -e 's/v//') || echo $(cat VERSION)-$(git log -1 --pretty='%h')) PRERELEASE=$(grep -q dev <<< "${VERSION}" && echo "pre" || echo "") REVISION=$(git log -1 --pretty='%h')
go build -ldflags="-X github.com/Mirantis/cri-dockerd/version.Version='$VERSION}' -X github.com/Mirantis/cri-dockerd/version.PreRelease='$PRERELEASE' -X github.com/Mirantis/cri-dockerd/version.BuildTime='$BUILD_DATE' -X github.com/Mirantis/cri-dockerd/version.GitCommit='$REVISION'" -o cri-dockerd
# Run these commands as root
###Install GO###
wget https://storage.googleapis.com/golang/getgo/installer_linux
chmod +x ./installer_linux
./installer_linux
source ~/.bash_profile

## build
cp -r /vagrant/files/cri-dockerd/ .
mkdir cri-dockerd/bin && cd cri-dockerd/bin
VERSION=$((git describe --abbrev=0 --tags | sed -e 's/v//') || echo $(cat VERSION)-$(git log -1 --pretty='%h')) PRERELEASE=$(grep -q dev <<< "${VERSION}" && echo "pre" || echo "") REVISION=$(git log -1 --pretty='%h')
go build -ldflags="-X github.com/Mirantis/cri-dockerd/version.Version='$VERSION}' -X github.com/Mirantis/cri-dockerd/version.PreRelease='$PRERELEASE' -X github.com/Mirantis/cri-dockerd/version.BuildTime='$BUILD_DATE' -X github.com/Mirantis/cri-dockerd/version.GitCommit='$REVISION'" -o cri-dockerd

## install
cd /root/cri-dockerd
# mkdir bin
# go build -o bin/cri-dockerd
mkdir -p /usr/local/bin
install -o root -g root -m 0755 bin/cri-dockerd /usr/local/bin/cri-dockerd
cp -a packaging/systemd/* /etc/systemd/system
sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl enable --now cri-docker.socket
systemctl status cri-docker.socket
```

#### install kubeamd kubectl kubelet
following https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
```sh
cd ~
apt-get update
apt-get install -y apt-transport-https ca-certificates curl
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
swapoff -a
```

### set up cluster
#### pre-pull images
```sh
kubeadm config images list
kubeadm config images pull --cri-socket=unix:///var/run/cri-dockerd.sock
```

####
```sh
unset http_proxy
unset https_proxy
kubeadm init --apiserver-advertise-address=192.168.50.4 --pod-network-cidr=192.168.0.0/16 --image-repository registry.aliyuncs.com/google_containers --cri-socket=unix:///var/run/cri-dockerd.sock | tee /tmp/kubadmin.output

```

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
