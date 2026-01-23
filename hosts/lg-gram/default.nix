{config, pkgs, lib, ...}:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/dwm
    ../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
  ];

  home-manager.users.frc = {
    imports = [
      ./home.nix
    ];
  };

  # Caps -> Ctrl (keep Right Alt as Level3 for dwm profile).
  services.xserver.xkb.options = lib.mkForce "lv3:ralt_switch,ctrl:nocaps";
}
