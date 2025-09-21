# /etc/nixos/home.nix
{ config, pkgs, lib, ... }:

{
  home.username = "nixos"; # ← 你的用户名
  home.homeDirectory = "/home/nixos"; # ← 你的家目录
  # 启用 home-manager
  home.stateVersion = "25.05";

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
    nodejs_20
    lazygit
    # uv
    uv
    # go
    go
  ];

  # 配置 shell (zsh)
  programs.zsh = {
    enable = true;
    enableCompletion = true;
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

    # 历史记录配置
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

  # 配置 git
  programs.git = {
    enable = true;
    userName = "fanrongchao";
    userEmail = "f@xfa.cn";
  };

  # 使用 home.file 来声明式地管理 .npmrc 文件
  home.file.".npmrc".text = ''
    prefix = ''${HOME}/.npm-global
    cache = ''${HOME}/.npm/.cache
    registry = https://registry.npmmirror.com
  '';
  # NPM 全局包通过 home.activation 安装
  home.activation.installNpmPackages = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -x "$(command -v npm)" ]; then
      echo "Installing global npm packages..."
      npm config set prefix ~/.npm-global
      npm install -g @google/gemini-cli @anthropic-ai/claude-code codex-cli opencode-ai || true
    fi
  '';

  # 环境变量
  home.sessionVariables = {
    EDITOR = "vi";
    VISUAL = "vi";
    GOOGLE_CLOUD_PROJECT = "gemini0cli";
  };

  # 通过 sessionPath 将 npm 全局目录添加到 PATH
  # 这是比修改 sessionVariables.PATH 或使用 extraProfileCommands 更可靠的方法
  home.sessionPath = [
    "$HOME/.npm-global/bin"
  ];

  # 启用 home-manager 来管理自身
  programs.home-manager.enable = true;
} 
