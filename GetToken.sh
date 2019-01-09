#!/bin/sh
# Install packages

kubeconfig="/etc/kubernetes/admin.conf"
user="admin-user"
usage()
{
    echo "Usage: $0 [-c altkubecfg.yaml] [-u user]"
    exit 1;
}

while getopts "c:u:" o; do
case "${o}" in
    c) kubeconfig="${OPTARG}"
        ;;
    u) user="${OPTARG}"
        ;;
    *) usage
        ;;
    esac
done

shift $((OPTIND-1))

echo -e "\033[36m      Retrieving Bearer Token for Dashboard Admin Account.\033[0m"
token=`kubectl --kubeconfig=$kubeconfig -n kube-system get secret | grep $user | awk '{print $1}'`
echo -e "\033[33m      $user Token is:\033[0m $token"
kubectl --kubeconfig=$kubeconfig -n kube-system describe secret $token


