{ lib
, stdenvNoCC
, fetchurl
, autoPatchelfHook
, python3
, python3Packages
, coreutils
, findutils
, gnugrep
, xdotool
, xclip
, xprop
, libnotify
, alsa-lib
, zlib
, libsndfile
, stdenv
}:

let
  sherpaBin = fetchurl {
    url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.12.25/sherpa-onnx-v1.12.25-linux-x64-static.tar.bz2";
    sha256 = "19lqyin1mz7iib74k05f9i6s4szjikaqrnqbs4r24x96s96r0x2f";
  };

  sherpaModel = fetchurl {
    url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-paraformer-bilingual-zh-en.tar.bz2";
    sha256 = "0pr01qlbb2qnsgs1zrjzm0mb293id32fiw9aaypdx4r6wkya2qjl";
  };

  pythonEnv = python3.withPackages (ps: with ps; [
    pynput
    sounddevice
    soundfile
    numpy
    pyyaml
  ]);

  runtimePath = lib.makeBinPath [
    coreutils
    findutils
    gnugrep
    xdotool
    xclip
    xprop
    libnotify
  ];
in
stdenvNoCC.mkDerivation rec {
  pname = "voice-input-sherpa-onnx";
  version = "0.1.0";

  src = ./app;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    alsa-lib
    zlib
    stdenv.cc.cc.lib
    libsndfile
  ];

  unpackPhase = ''
    runHook preUnpack
    cp -r "$src" app
    chmod -R u+w app
    mkdir -p external
    tar -xf ${sherpaBin} -C external
    tar -xf ${sherpaModel} -C external
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/voice-input-sherpa-onnx"
    cp -r app/* "$out/share/voice-input-sherpa-onnx/"

    mkdir -p "$out/share/voice-input-sherpa-onnx/sherpa-bin"
    cp -r external/sherpa-onnx-v1.12.25-linux-x64-static/bin/* "$out/share/voice-input-sherpa-onnx/sherpa-bin/"

    mkdir -p "$out/share/voice-input-sherpa-onnx/models"
    cp -r external/sherpa-onnx-streaming-paraformer-bilingual-zh-en "$out/share/voice-input-sherpa-onnx/models/"

    mkdir -p "$out/bin"
    cat > "$out/bin/voice-input-sherpa-onnx" <<EOF
    #!${stdenv.shell}
    set -euo pipefail

    export PATH="${runtimePath}:\$PATH"
    : "\''${VOICE_INPUT_SHERPA_CONFIG:=\$HOME/.config/voice-input-sherpa-onnx/config.yaml}"
    export VOICE_INPUT_SHERPA_CONFIG
    export SHERPA_ONNX_BIN_DIR="$out/share/voice-input-sherpa-onnx/sherpa-bin"
    export SHERPA_ONNX_MODEL_DIR="$out/share/voice-input-sherpa-onnx/models/sherpa-onnx-streaming-paraformer-bilingual-zh-en"

    cd "$out/share/voice-input-sherpa-onnx"
    exec ${pythonEnv}/bin/python main.py "\$@"
    EOF
    chmod +x "$out/bin/voice-input-sherpa-onnx"

    cat > "$out/bin/voice-input-tech-lexicon-sync" <<EOF
    #!${stdenv.shell}
    set -euo pipefail
    exec ${pythonEnv}/bin/python "$out/share/voice-input-sherpa-onnx/sync_tech_words.py" "\$@"
    EOF
    chmod +x "$out/bin/voice-input-tech-lexicon-sync"

    cat > "$out/bin/voice-input-learn-correction" <<EOF
    #!${stdenv.shell}
    set -euo pipefail
    exec ${pythonEnv}/bin/python "$out/share/voice-input-sherpa-onnx/learn_correction.py" "\$@"
    EOF
    chmod +x "$out/bin/voice-input-learn-correction"

    cat > "$out/bin/voice-input-learn-last" <<EOF
    #!${stdenv.shell}
    set -euo pipefail
    exec ${pythonEnv}/bin/python "$out/share/voice-input-sherpa-onnx/learn_correction.py" --from-last "\$@"
    EOF
    chmod +x "$out/bin/voice-input-learn-last"

    runHook postInstall
  '';

  meta = {
    description = "Local voice input using sherpa-onnx offline decoding";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "voice-input-sherpa-onnx";
  };
}
