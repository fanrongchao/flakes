lab/core (Kubernetes cluster)

- Bootstrap node (initial control-plane): lg-gram
- API endpoint name (LAN): k8s-core.lan
- Admin kubeconfig (kubeadm-compatible path): /etc/kubernetes/admin.conf

Notes

- This repo manages cluster *infrastructure* via NixOS (k3s server on lg-gram).
- This directory manages cluster *resources* (platform components and apps).
- Secrets should be managed via sops (do not commit plaintext Kubernetes Secret manifests).

LAN DNS

- Create a LAN DNS A record (or /etc/hosts entry): k8s-core.lan -> <lg-gram LAN IP>
