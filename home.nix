# /etc/nixos/home.nix
{ config, pkgs, lib, ... }:

{
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

    # 历史记录配置
    history = {
      expireDuplicatesFirst = false;
      extended = false;
      ignoreDups = false;
      ignoreSpace = true;
      share = true;
    };

    # zsh.initContent 中的命令式配置是不推荐的，我们将移除它
    # 并用 home-manager 的声明式选项替代
    initContent = "";
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

  # 使用 home.activation 来安装全局 npm 包
  home.activation.installNpmPackages = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -x "$(command -v npm)" ]; then
      $DRY_RUN_CMD npm install -g https://gaccode.com/claudecode/install --registry=https://registry.npmmirror.com
    fi
  '';

  # 环境变量
  home.sessionVariables = {
    EDITOR = "vi";
    VISUAL = "vi";
  };

  # 通过 sessionPath 将 npm 全局目录添加到 PATH
  # 这是比修改 sessionVariables.PATH 或使用 extraProfileCommands 更可靠的方法
  home.sessionPath = [
    "$HOME/.npm-global/bin"
  ];

  # home.extraProfileCommands 和 sessionVariables.PATH 已被 sessionPath 替代
  # 我们可以移除它们
} 