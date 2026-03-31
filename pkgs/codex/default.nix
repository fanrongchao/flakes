{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.117.0";
  releaseTag = "rust-v${version}";
  assets = {
    x86_64-linux = {
      asset = "codex-x86_64-unknown-linux-gnu.tar.gz";
      hash = "sha256:05c1decf82e9e8dd3dd7565352b447d55f481dd0d3b35afaab628e449d68895d";
    };
    aarch64-darwin = {
      asset = "codex-aarch64-apple-darwin.tar.gz";
      hash = "sha256:1e82f62b4d8f8ef9c0defcb0e68dc35da1687d2c8fb5e68ca2f441f3959987fd";
    };
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin.tar.gz";
      hash = "sha256:948d30f0d9b762de38f54a8de2e7c9420fab41190c5ce28b0c21bed5de7f1a32";
    };
  };
  assetInfo =
    assets.${stdenvNoCC.hostPlatform.system}
    or (throw "Unsupported platform for codex binary: ${stdenvNoCC.hostPlatform.system}");
  binaryName = lib.removeSuffix ".tar.gz" assetInfo.asset;
in
stdenvNoCC.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/${releaseTag}/${assetInfo.asset}";
    hash = assetInfo.hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    tar -xzf $src -C $TMPDIR
    install -m755 $TMPDIR/${binaryName} $out/bin/codex

    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI tool";
    homepage = "https://github.com/openai/codex";
    downloadPage = "https://github.com/openai/codex/releases/tag/${releaseTag}";
    license = licenses.asl20;
    mainProgram = "codex";
    platforms = builtins.attrNames assets;
  };
}
