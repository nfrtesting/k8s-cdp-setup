# k8s-cdp-setup
Sets up K8s with CDP packages
1.  Create OpenWRT VM, 128 MB using pre-made image
    *  Interface etho0 is the host network, defaults to 192.168.1.1
    *  Interface eth1 is the WAN bridge
    *  Edit /etc/config/network to change the default address.
        1.  Set the host network to xxx.yyy.zzz.2 (not .1!  the .1 is the openwrt)
2.  Create the VMs for Master and Nodes
    * 4+ GB Memory
    * 2+ CPUs required
    * 128+ GB storage
    * 1 NIC on the host network OpenWRT is routing for.
3.  Install CentOS.  Set boot and / (max), get rid of swap partition and /home, resize / to max possible.
    *  The reason for the resize is to maximize ephemeral storage.  You could put space at /var/lib/docker to isolate.
4.  Run SetupK8s.sh
    +  No parameters necessary on the Master unless you need to setup proxy or a different container network
    +  For nodes, use -w <master> and -t <token> if necessary.  Proxy setup flags same as for master.
    +  Flags information:
       + -k specifies K8s version #.  Default is -k "v1.13.1"
       + -p specifies a proxy host to use
       + -d used with proxy host, lists what to exclude from the proxy
       + -c cluster network.  Default is the network for the server.
       + -n container network.  Default is 10.244.0.0./16 for Weave
       + -t token.  Default is a static value, good for 24 hours, for bringing everything up.  This allows you to add a node later
       + -w specifies the IP/name of the master.   If you list this, it deploys as a worker node.  If omitted, assumes you want this node as master.
5.  Run InstallCDP.sh
    +  You can specify optional -c kubeconfig.yaml to point to a cluster other than default and -v k8s_ver, default is same as the install script.
