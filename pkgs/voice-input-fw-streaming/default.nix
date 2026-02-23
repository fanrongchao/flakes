{ lib
, stdenvNoCC
, python3
, python3Packages
, coreutils
, findutils
, gnugrep
, xdotool
, xclip
, xprop
, libnotify
, portaudio
, libsndfile
, libGL
, libxcb
, glib
, stdenv
, ffmpeg
, qt5
}:

let
  pythonEnv = python3.withPackages (ps: with ps; [
    faster-whisper
    pynput
    sounddevice
    numpy
    pyyaml
    webrtcvad
    setuptools
  ]);

  runtimeLibs = [
    portaudio
    libsndfile
    libGL
    libxcb
    glib
    stdenv.cc.cc.lib
    ffmpeg
  ];

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
  pname = "voice-input-fw-streaming";
  version = "0.1.0";

  src = ./app;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/voice-input-fw-streaming"
    cp -r . "$out/share/voice-input-fw-streaming/"

    mkdir -p "$out/bin"
    cat > "$out/bin/voice-input-fw-streaming" <<EOF
    #!${stdenv.shell}
    set -euo pipefail

    export PATH="${runtimePath}:\$PATH"
    export LD_LIBRARY_PATH="${lib.makeLibraryPath runtimeLibs}\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
    export QT_PLUGIN_PATH="${qt5.qtbase.bin}/${qt5.qtbase.qtPluginPrefix}"
    : "\''${QT_QPA_PLATFORM:=xcb}"
    export QT_QPA_PLATFORM
    : "\''${VOICE_INPUT_STREAMING_CONFIG:=\$HOME/.config/voice-input-streaming/config.yaml}"
    export VOICE_INPUT_STREAMING_CONFIG

    cd "$out/share/voice-input-fw-streaming"
    exec ${pythonEnv}/bin/python main.py "\$@"
    EOF
    chmod +x "$out/bin/voice-input-fw-streaming"

    runHook postInstall
  '';

  meta = {
    description = "Streaming-ish local voice input using faster-whisper";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "voice-input-fw-streaming";
  };
}
