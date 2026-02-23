{ config, lib, pkgs, ... }:

let
  cfg = config.voiceInput;
in
{
  options.voiceInput = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable voice-input profile on this host.";
    };

    model = lib.mkOption {
      type = lib.types.enum [ "small" "medium" "large-v3" "turbo" ];
      default = "medium";
      description = "Default local model.";
    };

    engine = lib.mkOption {
      type = lib.types.enum [ "whisper-writer" "fw-streaming" "sherpa-onnx" ];
      default = "whisper-writer";
      description = "Voice input engine to run.";
    };

    device = lib.mkOption {
      type = lib.types.enum [ "cpu" "cuda" ];
      default = "cpu";
      description = "Inference device.";
    };

    computeType = lib.mkOption {
      type = lib.types.str;
      default = "int8";
      description = "faster-whisper compute type.";
    };

    hotkey = lib.mkOption {
      type = lib.types.str;
      default = "ctrl+shift+space";
      description = "Activation hotkey.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Autostart user service in graphical session.";
    };

    backend = lib.mkOption {
      type = lib.types.enum [ "x11" "wayland" "auto" ];
      default = "x11";
      description = "Preferred backend for service tuning.";
    };

    streaming = {
      model = lib.mkOption {
        type = lib.types.enum [ "small" "medium" "large-v3" "turbo" ];
        default = "small";
        description = "Model used by faster-whisper streaming service.";
      };

      device = lib.mkOption {
        type = lib.types.enum [ "cpu" "cuda" ];
        default = "cpu";
        description = "Inference device for streaming service.";
      };

      computeType = lib.mkOption {
        type = lib.types.str;
        default = "int8";
        description = "Compute type for streaming service.";
      };

      chunkMs = lib.mkOption {
        type = lib.types.int;
        default = 320;
        description = "Audio chunk size in ms for streaming service.";
      };

      endpointMs = lib.mkOption {
        type = lib.types.int;
        default = 260;
        description = "Silence endpoint threshold in ms.";
      };

      maxUtteranceMs = lib.mkOption {
        type = lib.types.int;
        default = 12000;
        description = "Maximum utterance duration before forced finalize.";
      };
    };

    sherpa = {
      model = lib.mkOption {
        type = lib.types.enum [ "bilingual-small" "bilingual-medium" "zh-only-small" ];
        default = "bilingual-small";
        description = "Model profile used by sherpa-onnx service.";
      };

      sampleRate = lib.mkOption {
        type = lib.types.int;
        default = 16000;
        description = "Sample rate for sherpa-onnx recorder.";
      };

      chunkMs = lib.mkOption {
        type = lib.types.int;
        default = 320;
        description = "Audio chunk size in ms for sherpa-onnx service.";
      };

      endpointMs = lib.mkOption {
        type = lib.types.int;
        default = 260;
        description = "Reserved endpoint threshold in ms for sherpa-onnx.";
      };

      maxUtteranceMs = lib.mkOption {
        type = lib.types.int;
        default = 12000;
        description = "Maximum utterance duration before forced finalize.";
      };

      punctuationPolicy = lib.mkOption {
        type = lib.types.enum [ "light-normalize" "asr-raw" ];
        default = "light-normalize";
        description = "Post-processing policy for sherpa-onnx output text.";
      };

      interactionMode = lib.mkOption {
        type = lib.types.enum [ "hold-to-talk" "toggle" ];
        default = "hold-to-talk";
        description = "Hotkey interaction mode for sherpa-onnx.";
      };

      feedback = {
        recordingNotify = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Show recording status notification.";
        };

        thinkingNotify = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Show thinking status notification.";
        };

        doneNotify = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Show done notification after text injection.";
        };

        sound = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable feedback sounds.";
          };

          onStart = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Play sound when recording starts.";
          };

          onStop = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Play sound when recording stops and enters thinking.";
          };

          onDone = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Play sound when injection is done.";
          };

          theme = lib.mkOption {
            type = lib.types.str;
            default = "wispr-like";
            description = "Feedback sound theme.";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.portaudio
      pkgs.xdotool
    ];

    users.users.frc.extraGroups = [ "audio" "input" ];

    home-manager.users.frc = {
      imports = [ ./home.nix ];
      voiceInput = {
        enable = true;
        engine = cfg.engine;
        model = cfg.model;
        device = cfg.device;
        computeType = cfg.computeType;
        hotkey = cfg.hotkey;
        autoStart = cfg.autoStart;
        backend = cfg.backend;
        streaming = cfg.streaming;
        sherpa = cfg.sherpa;
        fallback.autoToFwStreaming = true;
      };
    };
  };
}
