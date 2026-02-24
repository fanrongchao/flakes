{ lib
, stdenvNoCC
, python312
, python312Packages
, coreutils
, findutils
, gnugrep
, xdotool
, xclip
, xprop
, libnotify
, ffmpeg
, alsa-lib
, zlib
, libsndfile
, stdenv
, torchPackage ? python312Packages.torch
, torchaudioPackage ? python312Packages.torchaudio
, openaiWhisperPackage ? python312Packages.openai-whisper
, includeOpenaiWhisper ? true
}:

let
  kaldiioPkg = python312Packages.buildPythonPackage rec {
    pname = "kaldiio";
    version = "2.18.1";
    format = "wheel";
    dontBuild = true;

    src = python312Packages.fetchPypi {
      inherit pname version;
      format = "wheel";
      dist = "py3";
      python = "py3";
      abi = "none";
      platform = "any";
      hash = "sha256-OXpM0Yl3rKrnrKv7poB+4KaXjGIAZDgaJm6sFbPBoKA=";
    };

    propagatedBuildInputs = with python312Packages; [
      numpy
    ];
    doCheck = false;
  };

  funasrPkg = python312Packages.buildPythonPackage rec {
    pname = "funasr";
    version = "1.3.1";
    format = "wheel";
    dontBuild = true;

    src = python312Packages.fetchPypi {
      inherit pname version;
      format = "wheel";
      dist = "py3";
      python = "py3";
      abi = "none";
      platform = "any";
      hash = "sha256-9jBQ19Yl8ofsdBuEoDJTZWmcSVUKS/06zkrLQ+Qah6g=";
    };

    propagatedBuildInputs = (with python312Packages; [
      kaldiioPkg
      editdistance
      hydra-core
      jaconv
      jamo
      jieba
      librosa
      modelscope
      oss2
      pyyaml
      requests
      scipy
      sentencepiece
      soundfile
      tensorboardx
      tqdm
      umap-learn
      torchPackage
      torchaudioPackage
      transformers
    ]) ++ lib.optionals includeOpenaiWhisper [
      openaiWhisperPackage
    ];

    pythonImportsCheck = [ ];
    dontUsePythonCatchConflicts = true;
    doCheck = false;
  };

  pythonEnv = python312.withPackages (ps: with ps; [
    funasrPkg
    pynput
    sounddevice
    soundfile
    numpy
    pyyaml
    torchPackage
    torchaudioPackage
    ps."huggingface-hub"
  ]);

  runtimePath = lib.makeBinPath [
    coreutils
    findutils
    gnugrep
    xdotool
    xclip
    xprop
    libnotify
    ffmpeg
  ];
in
stdenvNoCC.mkDerivation rec {
  pname = "voice-input-funasr-nano";
  version = "0.1.0";

  src = ./app;

  buildInputs = [
    alsa-lib
    zlib
    stdenv.cc.cc.lib
    libsndfile
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/voice-input-funasr-nano"
    cp -r . "$out/share/voice-input-funasr-nano/"

    mkdir -p "$out/bin"
    cat > "$out/bin/voice-input-funasr-nano" <<SCRIPT
    #!${stdenv.shell}
    set -euo pipefail

    export PATH="${runtimePath}:\$PATH"
    : "\''${VOICE_INPUT_FUNASR_NANO_CONFIG:=\$HOME/.config/voice-input-funasr-nano/config.yaml}"
    export VOICE_INPUT_FUNASR_NANO_CONFIG

    cd "$out/share/voice-input-funasr-nano"
    exec ${pythonEnv}/bin/python main.py "\$@"
    SCRIPT
    chmod +x "$out/bin/voice-input-funasr-nano"

    cat > "$out/bin/voice-input-funasr-tech-lexicon-sync" <<SCRIPT
    #!${stdenv.shell}
    set -euo pipefail
    exec ${pythonEnv}/bin/python "$out/share/voice-input-funasr-nano/sync_tech_words.py" "$@"
    SCRIPT
    chmod +x "$out/bin/voice-input-funasr-tech-lexicon-sync"

    cat > "$out/bin/voice-input-funasr-learn-correction" <<SCRIPT
    #!${stdenv.shell}
    set -euo pipefail
    exec ${pythonEnv}/bin/python "$out/share/voice-input-funasr-nano/learn_correction.py" "$@"
    SCRIPT
    chmod +x "$out/bin/voice-input-funasr-learn-correction"

    cat > "$out/bin/voice-input-funasr-learn-last" <<SCRIPT
    #!${stdenv.shell}
    set -euo pipefail
    exec ${pythonEnv}/bin/python "$out/share/voice-input-funasr-nano/learn_correction.py" --from-last "$@"
    SCRIPT
    chmod +x "$out/bin/voice-input-funasr-learn-last"

    runHook postInstall
  '';

  meta = {
    description = "Local voice input using FunASR Nano decoding";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "voice-input-funasr-nano";
  };
}
