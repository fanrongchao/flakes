{ config, pkgs, ... }:
{
  imports = [
    ../../profiles/workstation-ui/shared/home.nix
  ];

  home.file.".kube/config".source =
    config.lib.file.mkOutOfStoreSymlink "/etc/kubernetes/admin.conf";

  home.username = "frc";
  home.homeDirectory = "/home/frc";
  home.stateVersion = "25.11";
  home.packages = with pkgs; [
    #ai code cli
    codex
    claude-code
    gemini-cli-0_30_0
    opencode
    cursor-cli

    #home-manager self
    home-manager

    #ops tool
    htop
    btop
    lazygit
    yazi
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

    playwright-driver

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
    pencilOfficial
  ]; 


  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/flakes/dotfiles/astronvim";
  xdg.configFile."tmux/tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/flakes/dotfiles/tmux/tmux.conf";

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    mcp = {
      playwright = {
        type = "local";
        command = [ "npx" "-y" "@playwright/mcp@latest" ];
        environment = {
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
          PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
          PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "1";
        };
        enabled = true;
        timeout = 60000;
      };

      playwright_headless = {
        type = "local";
        command = [ "npx" "-y" "@playwright/mcp@latest" "--headless" ];
        environment = {
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
          PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
          PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "1";
        };
        enabled = true;
        timeout = 60000;
      };

      playwright_chrome = {
        type = "local";
        command = [ "npx" "-y" "@playwright/mcp@latest" "--browser" "chrome" ];
        environment = {
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
          PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
          PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "1";
        };
        enabled = true;
        timeout = 60000;
      };

      playwright_chrome_headless = {
        type = "local";
        command = [ "npx" "-y" "@playwright/mcp@latest" "--browser" "chrome" "--headless" ];
        environment = {
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
          PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
          PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "1";
        };
        enabled = true;
        timeout = 60000;
      };
    };
  };

  xdg.dataFile."applications/pencil.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Pencil
    GenericName=AI Coding Assistant
    Comment=Pencil Desktop
    Exec=pencil %U
    Icon=pencil
    Terminal=false
    Categories=Development;Utility;
    StartupNotify=true
    StartupWMClass=Pencil
  '';

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

  home.sessionVariables = {
    BROWSER = "google-chrome-stable";
  };

}
