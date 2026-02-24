{ config, pkgs, lib, ... }:
let
  openaiWhisperPatched = pkgs.python312Packages.openai-whisper.override {
    torch = pkgs.python312Packages.torch-bin;
    triton = pkgs.python312Packages.triton-bin;
  };
in
{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/dwm
    #../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
    ../../profiles/devops-baseline.nix
    ../../profiles/voice-input
  ];


  voiceInput = {
    enable = true;
    engine = "funasr-nano";
    device = "cuda";
    hotkey = "meta";
    autoStart = true;
    backend = "x11";
    funasrNano = {
      model = "/home/frc/.cache/huggingface/FunAudioLLM-Fun-ASR-Nano-2512";
      device = "cuda:0";
      dtype = "float16";
      chunkMs = 320;
      endpointMs = 260;
      maxUtteranceMs = 12000;
      punctuationPolicy = "light-normalize";
      interactionMode = "hold-to-talk";
      hotwordBoostEnable = true;
      hotwordBoostWeight = 0.75;
      learningMinHits = 2;
      autoLearnEnable = false;
      warmupOnStart = true;
      warmupBlockingStart = true;
      torchNumThreads = 10;
    };
  };

  home-manager.users.frc.voiceInput.funasrNanoPackage =
    pkgs.voice-input-funasr-nano.override {
      # Use prebuilt PyTorch wheels to avoid full torch source compilation.
      torchPackage = pkgs.python312Packages.torch-bin;
      torchaudioPackage = pkgs.python312Packages.torchaudio-bin;
      openaiWhisperPackage = openaiWhisperPatched;
    };

  home-manager.backupFileExtension = "bak";
}
