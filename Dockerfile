FROM centos/systemd:latest

##add perfSONAR nightly repo for perfsonar dependencies
RUN rpm -hUv http://software.internet2.edu/rpms/el7/x86_64/latest/packages/perfSONAR-repo-nightly-minor-0.10-1.noarch.rpm

#Install build environment dependencies
RUN yum update -y && \
    yum install -y epel-release make rpmbuild rpmdevtools && \
    yum install -y selinux-policy-devel perl-Test-MockObject perl-Test-Deep && \
    #yum install -y python3-sphinx python3-devel python3-six python3-setuptools && \
    # Fix to build python-dateutil
    #ln -s /usr/bin/sphinx-build-3 /usr/bin/sphinx-build && \
    yum clean all && \
    mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS} && \
    echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros

# Copy code to /app
COPY . /app

#Build RPMs
RUN cd /app && \
    make dist && \
    mv perfsonar-toolkit-*.tar.gz ~/rpmbuild/SOURCES/ && \
    rpmbuild -bs perfsonar-toolkit.spec && \
    rpmbuild -ba perfsonar-toolkit.spec

#shared volumes
VOLUME /sys/fs/cgroup

CMD ["/usr/sbin/init"]