{ config, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true; 
  home.username = "frc";
  home.homeDirectory = "/home/frc";
  home.stateVersion = "25.11";
  home.packages = with pkgs; [ 
    #test overlay
    myHello
    myCowsay

    home-manager
    htop
    btop
    lazygit
    tree
    fzf

#AstroNvim or LazyVim
    gcc
    gnumake
    pkg-config
    ripgrep
    fd
    nodejs
    python3

#fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
#nerd
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
    nerd-fonts.adwaita-mono
    nerd-fonts.code-new-roman
    nerd-fonts.ubuntu-mono
    nerd-fonts.meslo-lg
    nerd-fonts.caskaydia-cove

#lsp servers
    nixd
    lua-language-server 
  ]; 
  fonts.fontconfig.enable = true;


#dotfiles: do git clone git@github.com:fanrongchao/dotfiles.git ~/dotfiles/ first
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/astronvim";

#Chinese Inputs
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;   # turn off if you are on X11
        addons = with pkgs; [
        fcitx5-rime
          rime-data                # very important: gives luna_pinyin & others
          fcitx5-gtk               # makes input work inside apps
          fcitx5-chinese-addons    # extra tables & UI
        ];
    };
  };


  programs.neovim = {
    enable = true;
    vimAlias = true;
    defaultEditor = true;
    extraPackages = with pkgs; [
        lua-language-server
        nixd
        rust-analyzer
# CLI dependencies
        ripgrep fd fzf git
    ];
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" "fzf"];
    };

    shellAliases = {
      ll = "ls -la";
      la = "ls -A";
      l = "ls -CF";
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    history = {
      size = 10000;
      save = 10000;
      expireDuplicatesFirst = false;
      extended = false;
      ignoreDups = false;
      ignoreSpace = true;
      share = true;
    };
  };

  programs.kitty = {
    enable = true;

    font = {
      name = "CaskaydiaCove Nerd Font";
      size = 12;
    };

    settings = {
      enable_audio_bell     = "yes";
      remember_window_size  = "yes";
      window_padding_width  = 6;
      cursor_shape          = "beam";
      scrollback_lines      = 5000;
      confirm_os_window_close = 0;
    };

    shellIntegration = {
      enableZshIntegration = true;
    };

# Extra raw lines if you like:
    extraConfig = ''
      enable_wayland yes
      background_opacity 0.94
      cursor_beam_thickness 1.5
      disable_ligatures never
      line_height 1.5
      '';
  };

#key mapping
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      xkb-options = [ "ctrl:nocaps" ];
    };
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

  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "${config.xdg.dataHome}/npm";
    NPM_CONFIG_CACHE = "${config.xdg.cacheHome}/npm";
  };
  home.sessionPath = [ "${config.xdg.dataHome}/npm/bin" ];
}
