# Voice input – home-manager part.
# Sets up whisper-writer with a nix Python environment for native deps
# and a venv (--system-site-packages) for pip-only deps.
{ config, pkgs, lib, ... }:

let
  # Python with native packages that are hard to pip-install on NixOS
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pygobject3
    pycairo
    pyqt5
    sounddevice
    pynput
    cffi
    numpy
  ]);

  # Runtime native libraries
  nativeLibs = with pkgs; [
    portaudio
    libsndfile
    stdenv.cc.cc.lib
    libxcb
    libGL
    glib
    gobject-introspection
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    ffmpeg
  ];

  venvDir = "${config.home.homeDirectory}/.local/share/whisper-writer/venv";
  repoDir = "${config.home.homeDirectory}/.local/share/whisper-writer/repo";
  configDir = "${config.xdg.configHome}/whisper-writer";
  patchFile = ./whisper-writer.patch;

  whisperWriterScript = pkgs.writeShellScript "whisper-writer" ''
    set -euo pipefail

    VENV_DIR="${venvDir}"
    REPO_DIR="${repoDir}"
    CONFIG_DIR="${configDir}"

    export PATH="${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnugrep}/bin:${pkgs.xdotool}/bin:${pkgs.xclip}/bin:${pkgs.xorg.xprop}/bin:$PATH"
    export LD_LIBRARY_PATH="${lib.makeLibraryPath nativeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export GI_TYPELIB_PATH="${pkgs.gobject-introspection}/lib/girepository-1.0:${pkgs.gst_all_1.gstreamer.out}/lib/girepository-1.0:${pkgs.gst_all_1.gst-plugins-base.out}/lib/girepository-1.0''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
    export QT_QPA_PLATFORM="xcb"
    export QT_PLUGIN_PATH="${pkgs.qt5.qtbase.bin}/${pkgs.qt5.qtbase.qtPluginPrefix}"

    # Clone repo on first run
    if [ ! -d "$REPO_DIR/.git" ]; then
      echo "Cloning whisper-writer..."
      ${pkgs.git}/bin/git clone https://github.com/savbell/whisper-writer.git "$REPO_DIR"
    fi

    # Apply patches (idempotent: reset to upstream first)
    cd "$REPO_DIR"
    ${pkgs.git}/bin/git checkout -- . 2>/dev/null || true
    ${pkgs.git}/bin/git apply --whitespace=nowarn ${patchFile} || echo "Patch already applied or failed"

    # Create venv with system-site-packages (inherits nix Python packages)
    if [ ! -f "$VENV_DIR/.installed" ]; then
      echo "Creating Python venv..."
      rm -rf "$VENV_DIR"
      ${pythonEnv}/bin/python3 -m venv --system-site-packages "$VENV_DIR"
      source "$VENV_DIR/bin/activate"
      pip install --upgrade pip
      pip install \
        faster-whisper \
        soundfile \
        webrtcvad-wheels \
        pyperclip \
        pyyaml \
        coloredlogs \
        audioplayer \
        pydantic \
        openai \
        python-dotenv
      touch "$VENV_DIR/.installed"
    else
      source "$VENV_DIR/bin/activate"
    fi

    # Always symlink managed config into repo (overwrite any existing)
    ln -sf "$CONFIG_DIR/config.yaml" "$REPO_DIR/src/config.yaml"

    exec python src/main.py "$@"
  '';
in
{
  home.packages = with pkgs; [
    xclip          # clipboard backend for pyperclip on X11
    libnotify      # desktop notifications
  ];

  # Default config: medium model, auto language (Chinese+English), press_to_toggle mode
  xdg.configFile."whisper-writer/config.yaml".text = ''
    model_options:
      use_api: false
      common:
        language: null
        temperature: 0.0
        initial_prompt: "以下是普通话和English混合的句子。"
      local:
        model: medium
        device: cpu
        compute_type: int8
        condition_on_previous_text: true
        vad_filter: true
        model_path: null

    recording_options:
      activation_key: ctrl+shift+space
      input_backend: pynput
      recording_mode: press_to_toggle
      sound_device: null
      sample_rate: 16000
      silence_duration: 1500
      min_duration: 100

    post_processing:
      writing_key_press_delay: 0.005
      remove_trailing_period: false
      add_trailing_space: true
      remove_capitalization: false
      input_method: xdotool

    misc:
      print_to_terminal: true
      hide_status_window: false
      noise_on_completion: false
  '';

  # Launcher wrapper available as `whisper-writer` in PATH
  home.file.".local/bin/whisper-writer" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      exec ${whisperWriterScript} "$@"
    '';
  };

  # Systemd user service — starts after graphical session
  systemd.user.services.whisper-writer = {
    Unit = {
      Description = "WhisperWriter – local voice dictation";
      After = [ "graphical-session.target" "pipewire.service" ];
    };
    Service = {
      ExecStart = toString whisperWriterScript;
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "DISPLAY=:0"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
