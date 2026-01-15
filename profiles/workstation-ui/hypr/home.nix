{ config, pkgs, ... }:

{
  imports = [
    ../shared/home.nix
  ];

  home.packages = with pkgs; [
    # Core session tools
    waybar
    swaynotificationcenter
    fuzzel

    # Lock/idle
    hyprlock
    hypridle

    # Screenshot + annotate
    grim
    slurp
    swappy

    # Clipboard history
    wl-clipboard
    cliphist

    # Utilities
    pavucontrol
    brightnessctl
    polkit_gnome
  ];

  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
  };

  xdg.configFile."hypr/hyprland.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/hypr/hyprland.conf";

  xdg.configFile."hypr/hyprlock.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/hyprlock/hyprlock.conf";

  xdg.configFile."hypr/hypridle.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/hypridle/hypridle.conf";

  xdg.configFile."waybar".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/waybar";

  xdg.configFile."swaync".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/swaync";

  xdg.configFile."fuzzel".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/fuzzel";

  xdg.configFile."swappy".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/swappy";
}
