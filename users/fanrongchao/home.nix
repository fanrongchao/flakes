{ config, pkgs, lib, dotfiles, ... }:

{
  home.username = "fanrongchao"; # ← 你的用户名
  home.homeDirectory = "/home/fanrongchao"; # ← 你的家目录
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
    # lazyvim
    fzf
    unzip
    cargo
    rustc
    python3
    sqlite
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
  
  # 配置 nvim
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;  # LazyVim 有时需要
    withPython3 = true; # 若你用 python provider
    extraPackages = with pkgs; [ ripgrep fd ];
    plugins = with pkgs.vimPlugins; [
      (nvim-treesitter.withPlugins (p: [
        p.tree-sitter-bash
        p.tree-sitter-c
        p.tree-sitter-diff
        p.tree-sitter-dtd
        p.tree-sitter-html
        p.tree-sitter-javascript
        p.tree-sitter-json
        p.tree-sitter-jsonc
        p.tree-sitter-lua
        p.tree-sitter-luadoc
        p.tree-sitter-markdown
        p.tree-sitter-markdown-inline
        p.tree-sitter-python
        p.tree-sitter-query
        p.tree-sitter-regex
        p.tree-sitter-toml
        p.tree-sitter-tsx
        p.tree-sitter-typescript
        p.tree-sitter-vim
        p.tree-sitter-vimdoc
        p.tree-sitter-xml
        p.tree-sitter-yaml
      ]))
    ];
  };
  xdg.configFile."nvim".source = "${dotfiles}/nvim";


  # 使用 home.file 来声明式地管理 .npmrc 文件
  home.file.".npmrc".text = ''
    prefix = ''${HOME}/.npm-global
    cache = ''${HOME}/.npm/.cache
    registry = https://registry.npmmirror.com
  '';
  # NPM 全局包通过 home.activation 安装
  home.activation.installNpmPackages = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if command -v npm >/dev/null 2>&1; then
      npm config set prefix ~/.npm-global
      npm config set cache ~/.npm/.cache

      install_if_missing() {
        local pkg="$1"
        local label="$pkg"

        if [ $# -ge 2 ] && [ -n "$2" ]; then
          label="$2"
        fi

        if npm list -g "$pkg" >/dev/null 2>&1; then
          echo "npm package $label already present; skipping"
        else
          echo "Installing npm package $label..."
          if ! npm install -g "$pkg" --no-audit --no-fund --loglevel=error --progress=false; then
            echo "Warning: npm package $label failed to install; continuing" >&2
          fi
        fi
      }

      install_if_missing "@google/gemini-cli" "@google/gemini-cli"
      install_if_missing "@anthropic-ai/claude-code" "@anthropic-ai/claude-code"
      install_if_missing "codex-cli" "codex-cli"
      install_if_missing "opencode-ai" "opencode-ai"
    else
      echo "npm not in PATH; skipping global npm package installation"
    fi
  '';

  # 环境变量
  home.sessionVariables = {
    EDITOR = "vim";
    VISUAL = "vim";
  };

  # 通过 sessionPath 将 npm 全局目录添加到 PATH
  # 这是比修改 sessionVariables.PATH 或使用 extraProfileCommands 更可靠的方法
  home.sessionPath = [
    "$HOME/.npm-global/bin"
  ];

} 
