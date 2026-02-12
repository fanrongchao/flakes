final: prev: {
  #TODO: 1. add [x]codex/[x]claude code/[x]gemini/[ ]opencode/openspec ... npm install -g packages
  #      2. wrap sh and npm install -g pacakges and python app(uv) make them structural with helpers
  codex = prev.callPackage ../pkgs/codex {};

  # Pin claude-code ahead of nixpkgs when upstream lags.
  claude-code = prev.callPackage ../pkgs/claude-code {};

  dgop = prev.callPackage ../pkgs/dgop {};

  opencode =
    let
      version = "1.1.40";
      system = prev.stdenv.hostPlatform.system;
      src = prev.applyPatches {
        name = "opencode-${version}-src";
        src = prev.fetchFromGitHub {
          owner = "anomalyco";
          repo = "opencode";
          tag = "v${version}";
          hash = "sha256-n7EYPrF+Qjk9v9m/KzKtC6lG5Bt23ScFuQMLNkujz7Q=";
        };
        patches = [
          ./patches/opencode-gitlab-null-input.patch
        ];
      };
      hashes = builtins.fromJSON (builtins.readFile "${src}/nix/hashes.json");
      bunTarget = {
        "aarch64-linux" = "bun-linux-arm64";
        "x86_64-linux" = "bun-linux-x64";
        "aarch64-darwin" = "bun-darwin-arm64";
        "x86_64-darwin" = "bun-darwin-x64";
      };
      target =
        if builtins.hasAttr system bunTarget then
          bunTarget.${system}
        else
          throw "opencode: unsupported system ${system}";
      parts = prev.lib.splitString "-" target;
      bunPlatform = {
        os = builtins.elemAt parts 1;
        cpu = builtins.elemAt parts 2;
      };
      nodeModulesHash =
        if system == "x86_64-linux" then
          "sha256-9oI1gekRbjY6L8VwlkLdPty/9rCxC20EJlESkazEX8Y="
        else if builtins.hasAttr system hashes.nodeModules then
          hashes.nodeModules.${system}
        else
          throw "opencode: node_modules hash missing for ${system}";
      mkNodeModules = prev.callPackage "${src}/nix/node_modules.nix" {
        hash = nodeModulesHash;
        bunCpu = bunPlatform.cpu;
        bunOs = bunPlatform.os;
      };
      mkOpencode = prev.callPackage "${src}/nix/opencode.nix" {
        node_modules = mkNodeModules;
        models-dev = prev.models-dev;
      };
    in
    mkOpencode.overrideAttrs (_old: {
      version = version;
      __intentionallyOverridingVersion = true;
    });
}
