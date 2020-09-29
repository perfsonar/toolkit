# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # Build up to 10 el7 machines. toolkit-el7-0 is the default that will be the primary and 
  # autostart. Subsequent machines will not autostart. Each will have a full pscheduler 
  # install and maddash-server. The souce will live under /vagrant. You can access 
  # /etc/perfsonar in the shared directory /vagrant-data/vagrant/{hostname}/etc/perfsonar. 
  # Port forwarding is setup and hosts are on a private network with static IPv4 and IPv6 
  # addresses
  config.vm.define "toolkit-el7", primary: 1, autostart: 1 do |toolkit|
    # set box to official CentOS 7 image
    toolkit.vm.box = "centos/7"
    # explcitly set shared folder to virtualbox type. If not set will choose rsync 
    # which is just a one-way share that is less useful in this context
    toolkit.vm.synced_folder ".", "/vagrant", type: "virtualbox"
    # Set hostname
    toolkit.vm.hostname = "toolkit-el7"
    #increase memory
    toolkit.vm.provider "virtualbox" do |v|
        v.memory = 1024
    end

    # Enable IPv4. Cannot be directly before or after line that sets IPv6 address. Looks
    # to be a strange bug where IPv6 and IPv4 mixed-up by vagrant otherwise and one 
    #interface will appear not to have an address. If you look at network-scripts file
    # you will see a mangled result where IPv4 is set for IPv6 or vice versa
    toolkit.vm.network "private_network", ip: "10.0.0.21"
    
    # Setup port forwarding to apache
    toolkit.vm.network "forwarded_port", guest: 443, host: "21443", host_ip: "127.0.0.1"
    
    # Enable IPv6. Currently only supports setting via static IP. Address below in the
    # reserved local address range for IPv6
    toolkit.vm.network "private_network", ip: "fdac:218a:75e5:69c8::21"
    
    #Disable selinux
    toolkit.vm.provision "shell", inline: <<-SHELL
        sed -i s/SELINUX=enforcing/SELINUX=permissive/g /etc/selinux/config
    SHELL
    
    #reload VM since selinux requires reboot. Requires `vagrant plugin install vagrant-reload`
    toolkit.vm.provision :reload
    
    #Install all requirements and perform initial setup
    toolkit.vm.provision "shell", inline: <<-SHELL
        yum install -y epel-release
        yum install -y  http://software.internet2.edu/rpms/el7/x86_64/RPMS.main/perfSONAR-repo-0.9-1.noarch.rpm
        yum clean all
        yum install -y perfSONAR-repo-staging perfSONAR-repo-nightly
        yum clean all
        # NOTE:
        ## Install the toolkit RPM so all the setup stuff happens. May be kinda hacky
        ## but complicated enough setup that this is probably best
        yum install -y gcc\
            kernel-devel\
            kernel-headers\
            dkms\
            make\
            bzip2\
            perl-ExtUtils-MakeMaker\
            perl-Test-MockObject\
            perfsonar-toolkit
        ##
        # Now make install the shared directory
        cd /vagrant/shared
        make install
        ##
        # Make install the toolkit source
        cd /vagrant
        make install
    SHELL
  end
end

