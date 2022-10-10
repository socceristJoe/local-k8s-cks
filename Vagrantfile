Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-20.04"
  config.vm.box_download_insecure = true

   config.vm.provider "virtualbox" do |vb|
     vb.memory = "2048"
     vb.cpus = 2
   end

  config.vm.define "master" do | master|
    master.vm.network "private_network", ip: "192.168.50.4"
    master.vm.hostname = 'master.k8s.local'

  end
  config.vm.define "node" do | node|
    node.vm.network "private_network", ip: "192.168.50.5"
    node.vm.hostname = 'node.k8s.local'
  end
end
