{ config, pkgs, ... }:
{
  imports = [
    ../../profiles/workstation-ui/shared/home.nix
    ../../profiles/workstation-ui/hypr/home.nix
  ];

  home.username = "frc";
  home.homeDirectory = "/home/frc";
  home.stateVersion = "25.11";
  home.packages = with pkgs; [
    #ai code cli
    codex
    claude-code
    gemini-cli
    opencode
    cursor-cli

    #home-manager self
    home-manager

    #ops tool
    htop
    btop
    lazygit
    tree
    fzf
    jq
    bat
    procs
    bottom
    duf
    dust

    #tmux
    tmux

    #AstroNvim or LazyVim
    gcc
    gnumake
    pkg-config
    ripgrep
    fd
    nodejs
    python3
    unzip

    #lsp servers
    nixd
    lua-language-server 
    #lua formater
    stylua
    selene

    #github clli
    gh

    #chrome
    #secondary screen
  ]; 


  #dotfiles: do git clone git@github.com:fanrongchao/dotfiles.git ~/dotfiles/ first
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/astronvim";
  #tmux conf
  xdg.configFile."tmux/tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/tmux/tmux.conf";

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

}
