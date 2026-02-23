{ lib
, stdenvNoCC
, fetchFromGitHub
, python3
, python3Packages
, coreutils
, findutils
, gnugrep
, xdotool
, xclip
, xprop
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
    pyqt5
    pynput
    sounddevice
    soundfile
    webrtcvad
    pyperclip
    pyyaml
    coloredlogs
    pydantic
    openai
    python-dotenv
    numpy
    cffi
    evdev
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
  ];
in
stdenvNoCC.mkDerivation rec {
  pname = "whisper-writer";
  version = "unstable-2026-02-23";

  src = fetchFromGitHub {
    owner = "savbell";
    repo = "whisper-writer";
    rev = "370333b115417b03bf51c9f5bffd6578ecf6986e";
    hash = "sha256-NWh3FiKKSQsayIeqj2YsCw0aVa1dTY1GK9ccblOSDUw=";
  };

  patches = [
    ../../profiles/voice-input/whisper-writer.patch
  ];

  postPatch = ''
    # Provide a no-op audioplayer module when nixpkgs does not ship it.
    cat > src/audioplayer.py <<'EOF'
    class AudioPlayer:
        def __init__(self, *_args, **_kwargs):
            pass

        def play(self, block=True):
            return
    EOF

    substituteInPlace src/utils.py \
      --replace-fail "os.path.join('src', 'config.yaml')" "os.getenv('WHISPER_WRITER_CONFIG', os.path.join('src', 'config.yaml'))"

    # Start hidden in tray and auto-start hotkey listener; no manual click needed.
    substituteInPlace src/main.py \
      --replace-fail "self.main_window.show()" "self.main_window.hide()"
    sed -i '/self.main_window.hide()/a\        self.key_listener.start()' src/main.py

    # In terminal windows (e.g. kitty), use clipboard paste (Ctrl+Shift+V)
    # for exact text insertion to improve refill accuracy.
    substituteInPlace src/input_simulation.py \
      --replace-fail "Middle-click paste from primary selection (no bracketed paste)" "Paste from clipboard in terminals for exact text insertion"
    substituteInPlace src/input_simulation.py \
      --replace-fail "subprocess.run([\"xdotool\", \"click\", \"--window\", wid, \"2\"], timeout=5)" "subprocess.run([\"xdotool\", \"key\", \"--window\", wid, \"--clearmodifiers\", \"ctrl+shift+v\"], timeout=5)"
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/whisper-writer"
    cp -r . "$out/share/whisper-writer/"

    mkdir -p "$out/bin"
    cat > "$out/bin/whisper-writer" <<EOF
    #!${stdenv.shell}
    set -euo pipefail

    export PATH="${runtimePath}:\$PATH"
    export LD_LIBRARY_PATH="${lib.makeLibraryPath runtimeLibs}\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
    export QT_PLUGIN_PATH="${qt5.qtbase.bin}/${qt5.qtbase.qtPluginPrefix}"
    : "\''${QT_QPA_PLATFORM:=xcb}"
    export QT_QPA_PLATFORM
    : "\''${WHISPER_WRITER_CONFIG:=\$HOME/.config/whisper-writer/config.yaml}"
    export WHISPER_WRITER_CONFIG

    cd "$out/share/whisper-writer"
    exec ${pythonEnv}/bin/python src/main.py "\$@"
    EOF
    chmod +x "$out/bin/whisper-writer"

    runHook postInstall
  '';

  meta = {
    description = "Local voice dictation desktop app based on faster-whisper";
    homepage = "https://github.com/savbell/whisper-writer";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "whisper-writer";
  };
}
