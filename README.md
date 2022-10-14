# vagrant kubernetes bootstrap
This repo bootstrap 2 ubuntu VMs which is used to create K8s.


# pre-requirements
1. install virtualbox
brew install --cask virtualbox
for big sur, better download newest version from site
2. install vagrant
brew install --cask vagrant
 
# usage
cd /Users/joeqiao/Documents/LocalHub/cka/local-k8s-cks

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
hostnamectl set-hostname master.k8s.local
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
#### Letting iptables see bridged traffic
https://v1-23.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#letting-iptables-see-bridged-traffic
```sh
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
```
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
apt-get install -y kubelet=1.23.12-00 kubeadm=1.23.12-00 kubectl=1.23.12-00
apt-mark hold kubelet kubeadm kubectl
swapoff -a
```

### set up cluster
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
#### pre-pull images
```sh
kubeadm config images list
kubeadm config images pull --cri-socket=unix:///var/run/cri-dockerd.sock --image-repository registry.aliyuncs.com/google_containers
kubeadm config images pull --image-repository registry.aliyuncs.com/google_containers

```

#### initiate the cluster
```sh
unset http_proxy
unset https_proxy
kubeadm init --apiserver-advertise-address=192.168.50.4 --pod-network-cidr=10.244.0.0/16 --image-repository registry.aliyuncs.com/google_containers --cri-socket=unix:///var/run/cri-dockerd.sock | tee /tmp/kubadmin.output

kubeadm init --apiserver-advertise-address=192.168.50.4 --pod-network-cidr=10.244.0.0/16 --kubernetes-version=v1.23.12 --image-repository registry.aliyuncs.com/google_containers | tee /tmp/kubadmin.output

export KUBECONFIG=/etc/kubernetes/admin.conf
```
##### reset if init fails
```sh
systemctl daemon-reload 
systemctl restart kubelet 
systemctl status kubelet
kubeadm reset -f --cri-socket=unix:///var/run/cri-dockerd.sock
```
#### install network plugin
https://www.weave.works/docs/net/latest/kubernetes/kube-addon/#-installation
```sh
kubectl apply -f /vagrant/files/weavenet-2.8.1.yaml
```

## init node
### prepare host
#### login
```sh
vagrant ssh node
sudo su -
echo "192.168.50.4" master.k8s.local >> /etc/hosts
echo "192.168.50.5" node.k8s.local >> /etc/hosts
hostnamectl set-hostname node.k8s.local
```
#### install company certificate if any
http://www.noobyard.com/article/p-bqevkrkr-mx.html
```sh
mkdir /usr/share/ca-certificates/pg-ca
echo -n | openssl s_client -showcerts -connect production.cloudflare.docker.com:443 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /usr/share/ca-certificates/pg-ca/cloudfront.crt
cp /vagrant/files/proxy.crt /usr/share/ca-certificates/pg-ca/
cp /vagrant/files/pgrootca.cer /usr/share/ca-certificates/pg-ca/certificate.cer
openssl x509 -inform DER -in /usr/share/ca-certificates/pg-ca/certificate.cer -out /usr/share/ca-certificates/pg-ca/certificate.crt

cat >>/etc/ca-certificates.conf<<EOF
pg-ca/cloudfront.crt
pg-ca/proxy.crt
pg-ca/certificate.crt
EOF
update-ca-certificates --fresh
```
### install prerequesites
#### Letting iptables see bridged traffic
https://v1-23.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#letting-iptables-see-bridged-traffic
```sh
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
```
#### install container runtime
https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker
##### install docker engine
https://docs.docker.com/engine/install/ubuntu/
```sh
apt-get remove docker docker-engine docker.io containerd runc
apt-get update -y
apt-get install -y \
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
apt-get install -y docker-ce=5:19.03.15~3-0~ubuntu-focal docker-ce-cli=5:19.03.15~3-0~ubuntu-focal containerd.io docker-compose-plugin
apt-mark hold docker-ce docker-ce-cli containerd.io docker-compose-plugin
cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
systemctl enable docker
systemctl daemon-reload
systemctl start docker
systemctl status docker
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
apt-get update
apt-get install -y apt-transport-https ca-certificates curl
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=1.23.12-00 kubeadm=1.23.12-00 kubectl=1.23.12-00
apt-mark hold kubelet kubeadm kubectl

echo net.bridge.bridge-nf-call-iptables = 1 >> /etc/sysctl.d/99-sysctl.conf
echo 1 >/proc/sys/net/bridge/bridge-nf-call-iptables
# disable swap in /etc/fstab and ran swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a
```

### set up cluster
https://v1-23.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#join-nodes

#### initiate the cluster
```sh
unset http_proxy
unset https_proxy
systemctl daemon-reload 
systemctl start kubelet 
systemctl status kubelet
kubeadm join 192.168.50.4:6443 --token {{token}} --discovery-token-ca-cert-hash sha256:{{hash}}
```
reset if init fails
```sh
journalctl -xeu kubelet
systemctl daemon-reload 
systemctl restart kubelet 
systemctl status kubelet
kubeadm reset -f
```
