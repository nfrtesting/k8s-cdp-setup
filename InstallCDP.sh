#!/bin/sh
# Install packages

k8s_ver="v1.13.1"
kubeconfig="/etc/kubernetes/admin.conf"

usage()
{
    echo "Usage: $0 [-k k8s_ver] [-c altkubecfg.yaml]"
    exit 1;
}

while getopts "k:c:" o; do
case "${o}" in
    k) k8s_ver="${OPTARG}"
        ;;
    c) kubeconfig="${OPTARG}"
        ;;
    *) usage
        ;;
    esac
done

shift $((OPTIND-1))


case "${k8s_ver}" in
    "v1.13.1")
        DASHBOARD_VERSION="v1.10.1"
        ;;
    *)
        exit -1
        ;;
esac

echo -e "\033[1;32m--------------------------Installing K8s ($k8s_ver) Node------------------------------------\033[0m"
echo -e "\033[36mInstalling Dashboard.\033[0m"
echo -e "\033[1;33m    Version:\033[0m $DASHBOARD_VERSION"
echo -e "\033[36m      Deploying Dashboard.\033[0m"

kubectl --kubeconfig=$kubeconfig apply -f "https://raw.githubusercontent.com/kubernetes/dashboard/$DASHBOARD_VERSION/src/deploy/recommended/kubernetes-dashboard.yaml"
echo -e "\033[36m      Creating Service Account for Dashboard.\033[0m"
echo "
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
" | kubectl --kubeconfig=$kubeconfig apply -f -
./GetToken.sh -c $kubeconfig -u admin-user
echo -e "\033[36mInstalling Webpage of Links.\033[0m"
echo -e "\033[1;32m---------------------Master Node Installation Complete------------------------------\033[0m"
