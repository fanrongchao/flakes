{ config, pkgs, ... }:
{
  home.username = "xfa";
  home.homeDirectory = "/home/xfa";
  home.stateVersion = "25.05";
  home.packages = with pkgs; [
    #home-manager self
    home-manager

    #ops tool
    htop
    lazygit
    tree
    fzf
    jq
    bat
    bottom
    duf
    dust

  ]; 
  fonts.fontconfig.enable = true;

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
