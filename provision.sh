export https_proxy=https://approxy.pg.com:80
export http_proxy=http://approxy.pg.com:80

unset http_proxy
unset https_proxy

#!/usr/bin/env bash

$ cd /Users/joeqiao/Documents/LocalHub/cka/local-k8s
#ip4=$(/sbin/ip -o -4 addr list eth1 | awk '{print $4}' | cut -d/ -f1)
#host=$(hostname -f)
#sudo echo $ip4 $host >> /etc/hosts

sudo su -

echo "192.168.50.4" master.k8s.local >> /etc/hosts
echo "192.168.50.5" node.k8s.local >> /etc/hosts
# sudo echo "192.168.50.6" nfs.k8s.local >> /etc/hosts
#if [ "$1" != "" ]; 
#then
#	sudo echo $ip4 $1 >> /etc/hosts
#	ip4=$1
#fi

# if [ "$1" == "nfs" ]; then
#     #sudo yum install -y nfs-utils
#     sudo systemctl enable nfs-server.service
#     sudo systemctl start nfs-server.service
#     sudo mkdir -p /var/nfs
#     sudo chown nfsnobody:nfsnobody /var/nfs
#     sudo chmod 755 /var/nfs
#     sudo echo "/var/nfs *(rw,sync,no_subtree_check)" >> /etc/exports
#     sudo exportfs -a
#     exit 0
# fi

#cd /vagrant

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

mkdir -p /etc/systemd/system/docker.service.d
cat <<EOF | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://approxy.pg.com"
Environment="HTTPS_PROXY=http://approxy.pg.com"
EOF

echo -n | openssl s_client -showcerts -connect production.cloudflare.docker.com:443 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /usr/share/ca-certificates/pg-ca/cloudfront.crt

# sudo cp /vagrant/files/proxy.pem /usr/local/share/ca-certificates/
# sudo openssl x509 -outform der -in /usr/local/share/ca-certificates/proxy.pem -out /usr/local/share/ca-certificates/proxy.crt
# sudo rm /usr/local/share/ca-certificates/proxy.pem
mkdir /usr/share/ca-certificates/pg-ca/
cp /vagrant/files/proxy.crt /usr/share/ca-certificates/pg-ca/


cp /vagrant/files/pgrootca.cer /usr/share/ca-certificates/pg-ca/certificate.cer
openssl x509 -inform DER -in /usr/share/ca-certificates/pg-ca/certificate.cer -out /usr/share/ca-certificates/pg-ca/certificate.crt



# dpkg-reconfigure ca-certificates
cat >>/etc/ca-certificates.conf<<EOF
pg-ca/proxy.crt
pg-ca/certificate.crt
EOF
update-ca-certificates --fresh

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
systemctl restart docker

## test docker
docker run hello-world

apt-get update
apt-get install -y apt-transport-https ca-certificates curl

export https_proxy=http://approxy.pg.com:80
export http_proxy=http://approxy.pg.com:80
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

## remove cert check for apt via pg proxy
touch /etc/apt/apt.conf.d/proxy.conf \
&& echo >>/etc/apt/apt.conf.d/proxy.conf "Acquire { https::Verify-Peer false }"

apt-get update
apt-get install -y kubeadm=1.20.6-00 kubelet=1.20.6-00 kubectl=1.20.6-00
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

echo net.bridge.bridge-nf-call-iptables = 1 >> /etc/sysctl.d/99-sysctl.conf
echo 1 >/proc/sys/net/bridge/bridge-nf-call-iptables
# disable swap in /etc/fstab and ran swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a

if [ "$1" == "master" ]; then
    unset http_proxy
    unset https_proxy

    # vagrant only
    # use eth1 instead of eth0
    # for kubectl logs & exec cannot find
    # https://medium.com/@joatmon08/playing-with-kubeadm-in-vagrant-machines-part-2-bac431095706
    vim /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    ##add 
    Environment="KUBELET_EXTRA_ARGS=--node-ip=192.168.50.4"
    ##before "ExecStart="
    systemctl daemon-reload
    systemctl restart kubelet

    kubeadm init --apiserver-advertise-address=192.168.50.4 --pod-network-cidr=192.168.0.0/16 --kubernetes-version=v1.20.6 --image-repository registry.aliyuncs.com/google_containers | tee /tmp/kubadmin.output
    ##Note: If 192.168.0.0/16 is already in use within your network you must select a different pod network CIDR, replacing 192.168.0.0/16 in the above command.
    
    export KUBECONFIG=/etc/kubernetes/admin.conf


    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    kubectl apply -f /vagrant/files/calico.yaml
fi

if [ "$1" == "node" ]; then
    unset http_proxy
    unset https_proxy

    vim /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    ##add 
    Environment="KUBELET_EXTRA_ARGS=--node-ip=192.168.50.5"
    ##before "ExecStart="
    systemctl daemon-reload
    systemctl restart kubelet

    kubeadm join 192.168.50.4:6443 --token pddf5u.hz621if39juhacxk \
      --discovery-token-ca-cert-hash sha256:b68ff5b0afa2318961d133e1e483a4925bd63506e75b474f07b54644547577d8    
fi

# disable swap in /etc/fstab and ran swapoff -a
sed -i 's/^\/swap/#\/swap/' /etc/fstab
swapoff -a