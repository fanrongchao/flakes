{ config, pkgs, lib, ... }:

{
  imports = [
    ./compute-cluster-node.nix
  ];

  # Keep kubeconfig in the kubeadm conventional location.
  systemd.tmpfiles.rules = [
    "d /etc/kubernetes 0755 root root -"
  ];

  services.k3s = {
    enable = true;
    role = "server";

    # Prefer flags over module-specific options so this stays portable across
    # future Kubernetes distributions.
    extraFlags = [
      "--cluster-init"

      # Use a dedicated resolv.conf template for pods.
      "--resolv-conf /etc/k3s-resolv.conf"

      "--disable traefik"
      "--disable servicelb"

      "--write-kubeconfig /etc/kubernetes/admin.conf"
      "--write-kubeconfig-mode 0644"

      "--tls-san k8s-core.lan"
    ];
  };
}
