{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  nodejs,
}:

let
  version = "0.117.0";
  releaseTag = "rust-v${version}";
  system = stdenv.hostPlatform.system;
  isLinux = stdenv.hostPlatform.isLinux;

  linuxPlatforms = {
    x86_64-linux = {
      suffix = "linux-x64";
      hash = "sha256-6xb9TbJNQXPDezXUFdF6Z0HqrdRuGnHzT5LIa3djVgY=";
    };
    aarch64-linux = {
      suffix = "linux-arm64";
      hash = "sha256-Ywe0yIMdBPh6TD1Xp2+eFCPvz/zJj0Akmiij9PqL1+M=";
    };
  };

  darwinPlatforms = {
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin.tar.gz";
      hash = "sha256:1e82f62b4d8f8ef9c0defcb0e68dc35da1687d2c8fb5e68ca2f441f3959987fd";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin.tar.gz";
      hash = "sha256:948d30f0d9b762de38f54a8de2e7c9420fab41190c5ce28b0c21bed5de7f1a32";
    };
  };

  linuxInfo =
    linuxPlatforms.${system}
    or (throw "Unsupported platform for codex Linux package: ${system}");

  darwinInfo =
    darwinPlatforms.${system}
    or (throw "Unsupported platform for codex Darwin binary: ${system}");
in
if isLinux then
  stdenv.mkDerivation {
    pname = "codex";
    inherit version;

    src = fetchurl {
      url = "https://registry.npmmirror.com/@openai/codex/-/codex-${version}.tgz";
      hash = "sha256-r9uC9z1Vw9xcDsTeNyknOyibNnxmEbyQugve7KZ54Yk=";
    };

    platformSrc = fetchurl {
      url = "https://registry.npmmirror.com/@openai/codex/-/codex-${version}-${linuxInfo.suffix}.tgz";
      hash = linuxInfo.hash;
    };

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
    ];

    sourceRoot = ".";
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      tar -xzf $src
      cd package
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules/@openai/codex
      mkdir -p $out/bin

      cp -r . $out/lib/node_modules/@openai/codex/

      mkdir -p $TMPDIR/codex-platform
      tar -xzf ${"$"}platformSrc -C $TMPDIR/codex-platform
      mkdir -p $out/lib/node_modules/@openai/codex/node_modules/@openai
      cp -r $TMPDIR/codex-platform/package \
        $out/lib/node_modules/@openai/codex/node_modules/@openai/codex-${linuxInfo.suffix}

      makeWrapper ${nodejs}/bin/node $out/bin/codex \
        --add-flags "$out/lib/node_modules/@openai/codex/bin/codex.js"

      runHook postInstall
    '';

    meta = with lib; {
      description = "OpenAI Codex CLI tool";
      homepage = "https://github.com/openai/codex";
      license = licenses.asl20;
      mainProgram = "codex";
      platforms = builtins.attrNames linuxPlatforms;
    };
  }
else
  stdenvNoCC.mkDerivation {
    pname = "codex";
    inherit version;

    src = fetchurl {
      url = "https://github.com/openai/codex/releases/download/${releaseTag}/${darwinInfo.asset}";
      hash = darwinInfo.hash;
    };

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      tar -xzf $src -C $TMPDIR
      install -m755 $TMPDIR/${lib.removeSuffix ".tar.gz" darwinInfo.asset} $out/bin/codex

      runHook postInstall
    '';

    meta = with lib; {
      description = "OpenAI Codex CLI tool";
      homepage = "https://github.com/openai/codex";
      downloadPage = "https://github.com/openai/codex/releases/tag/${releaseTag}";
      license = licenses.asl20;
      mainProgram = "codex";
      platforms = builtins.attrNames darwinPlatforms;
    };
  }
