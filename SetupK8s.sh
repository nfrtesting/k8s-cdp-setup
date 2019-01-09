#!/bin/sh
# Set up a master node.
OS=`cat /etc/centos-release`
if [ "$OS" = "CentOS Linux release 7.6.1810 (Core)" ]
then
    myip=`hostname -I | cut -d' ' -f1`
    clusternet=`ip route | grep -v default | cut -d' ' -f1`
else
    echo "Requires [CentOS Linux release 7.6.1810 (Core)] but found [$OS]"
    exit -1
fi
myproxy="none"
dontproxy=""

#myproxy="one.proxy.att.com:8080"
#dontproxy=""

containernet="10.244.0.0/16"
token="123456.1234567890abcdef"
machine_type="master"

k8s_ver="v1.13.1"

usage()
{
    echo "Usage: $0 [-k k8s_ver] [-p proxy] [-i noproxy] [-c clusternet] [-t token] [-w masteraddr]"
    exit 1;
}

while getopts "k:p:i:c:n:t:w:" o; do
case "${o}" in
    k) k8s_ver="${OPTARG}"
        ;;
    p) myproxy="${OPTARG}"
        ;;
    i) dontproxy="${OPTARG}"
        ;;
    c) clusternet="${OPTARG}"
        ;;
    n) containernet="${OPTARG}"
        ;;
    t) token="${OPTARG}"
        ;;
    w) machine_type="${OPTARG}"
        ;;
    *) usage
        ;;
    esac
done

shift $((OPTIND-1))

echo -e "\033[1;32m--------------------------Installing K8s ($k8s_ver) Node------------------------------------\033[0m"
echo -e "\033[1;33m Configuration:\033[0m"
echo -e "\033[1;33m     Node IP:\033[0m $myip"
if [ "$machine_type" = "master" ] 
then
    echo -e "\033[1;33m     Node Type:\033[0m \033[1;33mMaster\033[0m"
    echo -e "\033[1;33m     Cluster Network:\033[0m $clusternet"
    echo -e "\033[1;33m     Pod Network:\033[0m $containernet"
else
    echo -e "\033[1;33m     Node Type:\033[0m \033[1;33mWorker\033[0m"
    echo -e "\033[1;33m     Master Node IP:Port:\033[0m $machine_type"
fi
echo -e "\033[1;33m     Initial Token:\033[0m $token"
if [ "$myproxy" = "none" ] 
then
    echo -e "\033[1;33m     Proxy Setup:\033[0m \033[1;31mfalse\033[0m"
else
    echo -e "\033[1;33m     Proxy Setup:\033[0m \033[1;32mtrue\033[0m"
fi
echo -e "\033[0m"
if [ "$myproxy" != "none" ] 
then
    echo -e "\033[36mWriting to /etc/environment\033[0m"
    echo -e "\033[36mReloading /etc/environment for this shell\033[0m"
fi

echo -e "\033[36mDisabling swap\033[0m"
swapoff -a
echo -e "\033[36mDisabling SELinux\033[0m"
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
echo -e "\033[36mDisabling firewalld\033[0m"
systemctl stop firewalld
systemctl disable firewalld
echo -e "\033[36mEnabling br_netfilter\033[0m"
modprobe br_netfilter
for SETTING in net.ipv4.conf.all.forwarding net.ipv4.conf.all.forwarding net.bridge.bridge-nf-call-iptables
do
    echo -e "\033[36mPersisting $SETTING=1\033[0m"
    sysctl $SETTING=1
    echo "$SETTING=1" >> /etc/sysctl.conf
done
echo -e "\033[36mSetting up repo for Docker \033[0m"
echo "
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://download.docker.com/linux/centos/7/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg
" > /etc/yum.repos.d/docker.repo
echo -e "\033[36mSetting up repo for Kubernetes\033[0m"
echo "
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
" > /etc/yum.repos.d/kubernetes.repo
echo -e "\033[36mSetting up repo for CEPH\033[0m"
echo "
[ceph]
name=Ceph packages for \$basearch
baseurl=https://download.ceph.com/rpm-luminous/el7/\$basearch
enabled=1
gpgcheck=1
priority=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-noarch]
name=Ceph NOARCH packages
baseurl=https://download.ceph.com/rpm-luminous/el7/noarch
enabled=1
gpgcheck=1
priority=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
" > /etc/yum.repos.d/ceph.repo
echo -e "\033[36mUpdating YUM repos\033[0m"
yum -y update
echo -e "\033[36mAdding EPEL\033[0m"
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
for PKG in docker-ce net-tools kubeadm kubectl ceph-common
do
    echo -e "\033[36mInstalling package:\033[0m $PKG"
    yum -y install $PKG
done
echo -e "\033[36mCustomizing Docker configuration\033[0m"
mkdir -p -m700 /root/.docker
echo -e "\033[36m    Adding insecure registry\033[0m"
if [ "$myproxy" != "none" ] 
then
    echo -e "\033[36m    Adding proxy\033[0m"
fi
echo -e "\033[36mIPTABLES configuration\033[0m"
iptables -P FORWARD ACCEPT
echo -e "\033[36mEnabling RBD\033[0m"
modprobe rbd
for SERVICE in docker kubelet
do
    echo -e "\033[36mBouncing $SERVICE and ensuring it's enabled on startup.\033[0m"
    systemctl stop $SERVICE
    systemctl start $SERVICE
    systemctl enable $SERVICE
    systemctl status $SERVICE
done

if [ "$machine_type" = "master" ] 
then
    echo -e "\033[36mRunning Kubeadm to create the cluster.\033[0m"
    kubeadm init --pod-network-cidr=$containernet --apiserver-advertise-address=$myip --token=$token
    echo -e "\033[36mInstalling weave.\033[0m"
    kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f "https://cloud.weave.works/k8s/net?k8s-version=$k8s_ver&env.IPALLOC_RANGE=$containernet"
    echo -e "\033[37mAdmin Context:\033[0m"
    cat /etc/kubernetes/admin.conf
else
    echo -e "\033[36mRunning Kubeadm to add this node to the cluster.\033[0m"
    kubeadm join --token 123456.1234567890abcdef $machine_type:6443 --discovery-token-unsafe-skip-ca-verification

fi

echo -e "\033[1;32m---------------------Master Node Installation Complete------------------------------\033[0m"
