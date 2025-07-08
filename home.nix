# /etc/nixos/home.nix
{ config, pkgs, ... }:

{
  # 启用 home-manager
  home.stateVersion = "25.05";

  # 配置备份文件扩展名，避免覆盖现有文件
  home-manager.backupFileExtension = "backup";

  # 安装一些常用的包
  home.packages = with pkgs; [
    # home-manager 本身
    home-manager
    # 开发工具
    git
    vim
    htop
    tree
    # 网络工具
    curl
    wget
    # 其他工具
    ripgrep
    fd
    bat
  ];

  # 配置 shell (zsh)
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # 修复已弃用的选项
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    # 自定义别名
    shellAliases = {
      ll = "ls -la";
      la = "ls -A";
      l = "ls -CF";
      ".." = "cd ..";
      "..." = "cd ../..";
    };
  };

  # 配置 git
  programs.git = {
    enable = true;
    userName = "fanrongchao";
    userEmail = "f@xfa.cn";
  };
} 