{ lib
, stdenvNoCC
, python312
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
}:

let
  pythonEnv = python312.withPackages (ps: with ps; [
    pynput
    sounddevice
    soundfile
    numpy
    pyyaml
    torch
    torchaudio
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

    VENV_DIR="\$HOME/.cache/voice-input-funasr-nano/venv"
    DEPS_MARK="\$VENV_DIR/.deps.v3.ready"
    if [ ! -x "\$VENV_DIR/bin/python" ]; then
      mkdir -p "\$HOME/.cache/voice-input-funasr-nano"
      ${pythonEnv}/bin/python -m venv --system-site-packages "\$VENV_DIR"
    fi
    if [ ! -f "\$DEPS_MARK" ]; then
      "\$VENV_DIR/bin/python" -m pip install --upgrade pip >/dev/null 2>&1 || true
      "\$VENV_DIR/bin/python" -m pip install "funasr>=1.2.0" "modelscope>=1.20.0" "transformers>=4.49.0" "openai-whisper>=20240930" >/dev/null
      touch "\$DEPS_MARK"
    fi

    cd "$out/share/voice-input-funasr-nano"
    exec "\$VENV_DIR/bin/python" main.py "\$@"
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
