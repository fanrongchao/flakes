{ config, pkgs, lib, ... }:
{
  nixpkgs.config.allowUnfree = true; 
  home.username = "frc";
  home.homeDirectory = "/home/frc";
  home.stateVersion = "25.11";
  home.packages = with pkgs; [ 
    home-manager
    htop
    btop
    lazygit
    tree

    #AstroNvim or LazyVim
    gcc
    gnumake
    pkg-config
    ripgrep
    fd
    nodejs
    python3
  ]; 

  #dotfiles: do git clone git@github.com:fanrongchao/dotfiles.git ~/dotfiles/ first
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/astronvim";



  programs.neovim = {
    enable = true;
    vimAlias = true;
    defaultEditor = true;
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
