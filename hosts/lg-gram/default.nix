{config, pkgs, lib, ...}:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/dwm
    ../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
  ];

  home-manager.users.frc.imports = [
    ./home.nix
  ];
}
