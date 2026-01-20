final: prev: {
  #TODO: 1. add [x]codex/[x]claude code/[x]gemini/[ ]opencode/openspec ... npm install -g packages
  #      2. wrap sh and npm install -g pacakges and python app(uv) make them structural with helpers
  codex = prev.callPackage ../pkgs/codex {};

  opencode =
    let
      version = "1.1.26";
      system = prev.stdenv.hostPlatform.system;
      src = prev.applyPatches {
        name = "opencode-${version}-src";
        src = prev.fetchFromGitHub {
          owner = "sst";
          repo = "opencode";
          tag = "v${version}";
          hash = "sha256-3PpnLiVB+MxnWmdKolUpQ9BQf7nzzRQhoTsL8m0eIBA=";
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
          "sha256-cSuB6jv9J5IaAxXrZ+JZo45SbxkHb18sd4ICYLoqKKY="
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
