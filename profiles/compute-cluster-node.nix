{ config, pkgs, lib, ... }:

{
  # Kubernetes node baseline (intended to be reusable across k3s/kubeadm/etc.).

  # Kubelet uses this as a template for pod resolv.conf. Keep host search domains
  # out (eg. tailnet domains) and lower ndots so Kubernetes service FQDNs don't
  # get resolver-expanded into non-cluster domains.
  environment.etc."k3s-resolv.conf".text = ''
    nameserver 1.1.1.1
    options ndots:2
  '';

  boot.kernelModules = lib.mkBefore [
    "br_netfilter"
    "overlay"
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = lib.mkDefault 1;
    "net.bridge.bridge-nf-call-iptables" = lib.mkDefault 1;
    "net.bridge.bridge-nf-call-ip6tables" = lib.mkDefault 1;
  };

  # Avoid NetworkManager interfering with CNI-managed interfaces.
  networking.networkmanager.unmanaged = lib.mkBefore [
    "interface-name:cni0"
    "interface-name:flannel.1"
  ];

  # Forward-looking defaults (only relevant when firewall is enabled).
  networking.firewall.allowedTCPPorts = lib.mkDefault [
    6443
  ];
  networking.firewall.allowedUDPPorts = lib.mkDefault [
    8472
  ];

  environment.systemPackages = lib.mkAfter (with pkgs; [
    kubectl
    kubernetes-helm
    kustomize
    cri-tools
  ]);
}
