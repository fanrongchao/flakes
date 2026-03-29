{ pkgs, ... }:

{
  home.username = "frc";
  home.homeDirectory = "/Users/frc";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    bat
    btop
    direnv
    eza
    fd
    fzf
    gh
    git
    jq
    just
    nerd-fonts.caskaydia-cove
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    ripgrep
    tmux
    tree
    yq-go
    zoxide
  ];

  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" "fzf" ];
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
