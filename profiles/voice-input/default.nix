# Voice input via whisper-writer (local Whisper-based dictation).
# System-level native dependencies required by the Python venv.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    portaudio        # sounddevice native dep
    xdotool          # X11 utility (useful for focus debugging)
  ];

  # evdev input backend needs access to /dev/input/*
  users.users.frc.extraGroups = [ "input" "audio" ];

  home-manager.users.frc.imports = [
    ./home.nix
  ];
}
