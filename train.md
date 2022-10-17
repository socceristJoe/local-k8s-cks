```sh
cd /Users/joeqiao/Documents/LocalHub/cka/local-k8s-cks
vagrant up
vagrant ssh master
export KUBECONFIG=/etc/kubernetes/admin.conf

cd /root/LFS260-1/SOLUTIONS/s_04/
cd /root/LFS260-2/SOLUTIONS/s_05/

curl -H "Authorization: Bearer $TOKEN" \https://192.168.50.4:6443/api/v1/namespaces/prod-a/pods/ --insecure

kubectl -n kube-system exec -it etcd-master.k8s.local -- sh -c \
"ETCDCTL_API=3 \
ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt \
ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt \
ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key \
etcdctl --endpoints=https://127.0.0.1:2379 \
get /registry/secrets/default/first"

kubectl -n kube-system exec -it etcd-master.k8s.local -- sh -c \
"ETCDCTL_API=3 \
ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt \
ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt \
ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key \
etcdctl --endpoints=https://127.0.0.1:2379 \
get /registry/secrets/default/second"
```