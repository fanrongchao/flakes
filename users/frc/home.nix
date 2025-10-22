{ config, pkgs, lib, dotfiles, ... }:
{
  nixpkgs.config.allowUnfree = true; 
  home.username = "frc";
  home.homeDirectory = "/home/frc";
  home.stateVersion = "25.05";
  home.packages = with pkgs; [ 
    home-manager
    htop
    #google-chrome
  ]; 
  programs.neovim = {
    enable = true;
    vimAlias = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
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
