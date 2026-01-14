final: prev: {
  #TODO: 1. add [x]codex/[x]claude code/[x]gemini/[ ]opencode/openspec ... npm install -g packages
  #      2. wrap sh and npm install -g pacakges and python app(uv) make them structural with helpers
  codex = prev.callPackage ../pkgs/codex {};

  opencode =
    let
      version = "1.1.19";
      system = prev.stdenv.hostPlatform.system;
      src = prev.applyPatches {
        name = "opencode-${version}-src";
        src = prev.fetchFromGitHub {
          owner = "sst";
          repo = "opencode";
          tag = "v${version}";
          hash = "sha256-dG8d40Q2iG738yhgu7y9ijYY3hWG7N0Fqjj1EvXMeLs=";
        };
        patches = [
          ./patches/opencode-gitlab-null-input.patch
          ./patches/opencode-libc-define.patch
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
          "sha256-ZkELIjvsWNy2Da6owVOgD1n9s8RP/Fr4X02zzbrJFzI="
        else if builtins.hasAttr system hashes.nodeModules then
          hashes.nodeModules.${system}
        else
          throw "opencode: node_modules hash missing for ${system}";
      mkNodeModules = prev.callPackage "${src}/nix/node-modules.nix" {
        hash = nodeModulesHash;
        bunCpu = bunPlatform.cpu;
        bunOs = bunPlatform.os;
      };
      mkOpencode = prev.callPackage "${src}/nix/opencode.nix" { };
    in
    mkOpencode {
      inherit version src mkNodeModules;
      scripts = "${src}/nix/scripts";
      modelsDev = "${prev.models-dev}/dist/_api.json";
    };
}
