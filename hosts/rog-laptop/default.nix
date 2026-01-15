{ config, pkgs, lib, ... }:
{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/hypr
    ../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
  ];

  # Use Hypr ricing from ~/dotfiles on this host.
  home-manager.users.frc = {
    imports = [
      ../../profiles/workstation-ui/hypr/home.nix
    ];

    # Override tmux config to use dotfiles on this host.
    xdg.configFile."tmux/tmux.conf" = lib.mkForce {
      text = ''
        source-file ~/dotfiles/tmux/tmux.conf
        source-file ~/dotfiles/tmux/theme.conf
      '';
    };
  };

  home-manager.backupFileExtension = "bak";
}
