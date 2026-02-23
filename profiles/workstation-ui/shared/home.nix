{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji

    # nerd fonts
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
    nerd-fonts.adwaita-mono
    nerd-fonts.code-new-roman
    nerd-fonts.ubuntu-mono
    nerd-fonts.meslo-lg
    nerd-fonts.caskaydia-cove

    # desktop apps
    google-chrome
    input-leap
  ];

  fonts.fontconfig.enable = true;

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true; # turn off if you are on X11
      addons = with pkgs; [
        fcitx5-rime
        rime-data
        fcitx5-gtk
        qt6Packages.fcitx5-chinese-addons
      ];
    };
  };

  xdg.configFile."fcitx5" = {
    source = ./fcitx5;
    force = true;
  };

  xdg.configFile."rime" = {
    source = ./rime;
    force = true;
  };

  programs.kitty = {
    enable = true;

    font = {
      name = "CaskaydiaCove Nerd Font";
      size = 12;
    };

    settings = {
      enable_audio_bell = "yes";
      remember_window_size = "yes";
      window_padding_width = 6;
      cursor_shape = "beam";
      scrollback_lines = 5000;
      confirm_os_window_close = 0;
    };

    shellIntegration = {
      enableZshIntegration = true;
    };

    extraConfig = ''
      # Work on both Wayland (Hyprland) and X11 (dwm) hosts.
      linux_display_server auto
      background_opacity 0.94
      cursor_beam_thickness 1.5
      disable_ligatures never
      line_height 1.5
      include ~/.config/kitty/theme.conf
    '';
  };

  xdg.desktopEntries.kitty = {
    name = "Kitty";
    comment = "Fast, GPU-accelerated terminal";
    exec = "kitty";
    icon = "kitty";
    terminal = false;
    categories = [ "System" "TerminalEmulator" ];
    startupNotify = true;
  };
}
