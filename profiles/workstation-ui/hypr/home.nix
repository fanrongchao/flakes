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
    polkit-kde-agent
  ];

  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
  };

  xdg.configFile."hypr".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/hypr";

  xdg.configFile."waybar".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/waybar";

  xdg.configFile."swaync".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/swaync";

  xdg.configFile."fuzzel".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/fuzzel";

  xdg.configFile."hyprlock".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/hyprlock";

  xdg.configFile."hypridle".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/hypridle";

  xdg.configFile."swappy".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/swappy";
}
