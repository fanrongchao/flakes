{config, pkgs, lib, ...}:

{
  imports = [
    ./configuration.nix
    #profiles
    ../../profiles/workstation-ui/dwm
    ../../profiles/container-runtime
    ../../profiles/zero-trust-node.nix
    ../../profiles/network-egress-proxy.nix
    ../../profiles/devops-baseline.nix
    ../../profiles/voice-input
  ];

  home-manager.users.frc.imports = [
    ./home.nix
  ];

  containerRuntime = {
    enable = true;
    dockerCompat = true;
  };

  voiceInput = {
    enable = true;
    engine = "funasr-nano";
    model = "medium";
    device = "cpu";
    computeType = "int8";
    hotkey = "meta";
    autoStart = true;
    backend = "x11";
    funasrNano = {
      model = "/home/frc/.cache/huggingface/FunAudioLLM-Fun-ASR-Nano-2512";
      device = "cpu";
      dtype = "float32";
      chunkMs = 320;
      endpointMs = 260;
      maxUtteranceMs = 12000;
      punctuationPolicy = "light-normalize";
      interactionMode = "hold-to-talk";
      hotwordBoostEnable = true;
      hotwordBoostWeight = 0.6;
      learningMinHits = 2;
    };
  };
}
