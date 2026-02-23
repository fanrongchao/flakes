{ config, lib, pkgs, ... }:

let
  cfg = config.voiceInput;
  inputMethod = if cfg.backend == "x11" then "xdotool" else "pynput";
  qtPlatform = if cfg.backend == "wayland" then "wayland" else "xcb";
in
{
  options.voiceInput = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable voice input for this Home Manager user.";
    };

    engine = lib.mkOption {
      type = lib.types.enum [ "whisper-writer" "fw-streaming" "sherpa-onnx" "funasr-nano" ];
      default = "whisper-writer";
      description = "Voice input engine to autostart.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.whisper-writer-pinned;
      description = "WhisperWriter package.";
    };

    streamingPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.voice-input-fw-streaming;
      description = "faster-whisper streaming package.";
    };

    sherpaPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.voice-input-sherpa-onnx;
      description = "sherpa-onnx package.";
    };

    funasrNanoPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.voice-input-funasr-nano;
      description = "funasr-nano package.";
    };

    model = lib.mkOption {
      type = lib.types.enum [ "small" "medium" "large-v3" "turbo" ];
      default = "medium";
      description = "Default local model name for whisper-writer.";
    };

    device = lib.mkOption {
      type = lib.types.enum [ "cpu" "cuda" ];
      default = "cpu";
      description = "Compute device for whisper-writer.";
    };

    computeType = lib.mkOption {
      type = lib.types.str;
      default = "int8";
      description = "Compute type for whisper-writer.";
    };

    hotkey = lib.mkOption {
      type = lib.types.str;
      default = "ctrl+shift+space";
      description = "Activation hotkey.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start selected engine with graphical session.";
    };

    backend = lib.mkOption {
      type = lib.types.enum [ "x11" "wayland" "auto" ];
      default = "x11";
      description = "Desktop backend preference for runtime tuning.";
    };

    streaming = {
      model = lib.mkOption {
        type = lib.types.enum [ "small" "medium" "large-v3" "turbo" ];
        default = "small";
        description = "Model used by streaming engine.";
      };

      device = lib.mkOption {
        type = lib.types.enum [ "cpu" "cuda" ];
        default = "cpu";
        description = "Inference device used by streaming engine.";
      };

      computeType = lib.mkOption {
        type = lib.types.str;
        default = "int8";
        description = "Compute type used by streaming engine.";
      };

      language = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional language code for streaming engine.";
      };

      initialPrompt = lib.mkOption {
        type = lib.types.str;
        default = "中英混合听写。逐字转写，保留阿拉伯数字与英文原样。不要把英文翻译成中文，不要臆测补全，不要重复前文，尽量不要自动添加标点。示例：English ABC -> English ABC；OpenAI GPT 4.1 -> OpenAI GPT 4.1；今天试123 -> 今天试123。";
        description = "Prompt for streaming engine.";
      };

      chunkMs = lib.mkOption {
        type = lib.types.int;
        default = 320;
        description = "Audio chunk size in milliseconds.";
      };

      endpointMs = lib.mkOption {
        type = lib.types.int;
        default = 260;
        description = "Silence endpoint threshold in milliseconds.";
      };

      maxUtteranceMs = lib.mkOption {
        type = lib.types.int;
        default = 12000;
        description = "Maximum utterance length in milliseconds.";
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
        description = "Audio chunk size in milliseconds.";
      };

      endpointMs = lib.mkOption {
        type = lib.types.int;
        default = 260;
        description = "Reserved endpoint threshold in milliseconds.";
      };

      maxUtteranceMs = lib.mkOption {
        type = lib.types.int;
        default = 12000;
        description = "Maximum utterance length in milliseconds.";
      };

      punctuationPolicy = lib.mkOption {
        type = lib.types.enum [ "light-normalize" "asr-raw" ];
        default = "light-normalize";
        description = "Post-processing policy for sherpa output.";
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

    funasrNano = {
      model = lib.mkOption {
        type = lib.types.str;
        default = "FunAudioLLM/Fun-ASR-Nano-2512";
        description = "Model repo/profile used by funasr-nano service.";
      };

      device = lib.mkOption {
        type = lib.types.str;
        default = "cpu";
        description = "Inference device for funasr-nano (e.g. cpu, cuda:0).";
      };

      dtype = lib.mkOption {
        type = lib.types.str;
        default = "float32";
        description = "Preferred dtype hint for funasr-nano inference.";
      };

      sampleRate = lib.mkOption {
        type = lib.types.int;
        default = 16000;
        description = "Sample rate for funasr-nano recorder.";
      };

      chunkMs = lib.mkOption {
        type = lib.types.int;
        default = 320;
        description = "Audio chunk size in milliseconds.";
      };

      endpointMs = lib.mkOption {
        type = lib.types.int;
        default = 260;
        description = "Reserved endpoint threshold in milliseconds.";
      };

      maxUtteranceMs = lib.mkOption {
        type = lib.types.int;
        default = 12000;
        description = "Maximum utterance length in milliseconds.";
      };

      punctuationPolicy = lib.mkOption {
        type = lib.types.enum [ "light-normalize" "asr-raw" ];
        default = "light-normalize";
        description = "Post-processing policy for funasr-nano output.";
      };

      interactionMode = lib.mkOption {
        type = lib.types.enum [ "hold-to-talk" "toggle" ];
        default = "hold-to-talk";
        description = "Hotkey interaction mode for funasr-nano.";
      };

      hotwordBoostEnable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable tech lexicon hotword boost for funasr-nano.";
      };

      hotwordBoostWeight = lib.mkOption {
        type = lib.types.float;
        default = 0.6;
        description = "Hotword boost weight used by funasr-nano.";
      };

      learningMinHits = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Minimum repeated corrections before auto rule promotion.";
      };

      autoLearnEnable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable auto-learning correction updates during transcription.";
      };

      warmupOnStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Warm up FunASR model once at service startup.";
      };

      warmupBlockingStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Block service readiness until warmup finishes to avoid first-use lag.";
      };

      torchNumThreads = lib.mkOption {
        type = lib.types.int;
        default = 8;
        description = "Torch CPU threads used by funasr-nano.";
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

    fallback = {
      autoToWhisperWriter = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Auto fallback to whisper-writer when streaming startup fails.";
      };

      autoToFwStreaming = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Auto fallback to fw-streaming when sherpa/funasr startup fails.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      cfg.streamingPackage
      cfg.sherpaPackage
      cfg.funasrNanoPackage
      pkgs.xclip
      pkgs.libnotify
    ];

    xdg.configFile."whisper-writer/config.yaml" = {
      force = true;
      text = ''
      model_options:
        use_api: false
        common:
          language: null
          temperature: 0.0
          initial_prompt: "中英混合听写。逐字转写，保留阿拉伯数字与英文原样。不要把英文翻译成中文，不要臆测补全，不要重复前文，尽量不要自动添加标点。示例：English ABC -> English ABC；OpenAI GPT 4.1 -> OpenAI GPT 4.1；今天试123 -> 今天试123。"
        local:
          model: ${cfg.model}
          device: ${cfg.device}
          compute_type: ${cfg.computeType}
          condition_on_previous_text: false
          vad_filter: true
          model_path: null

      recording_options:
        activation_key: ${cfg.hotkey}
        input_backend: pynput
        recording_mode: press_to_toggle
        sound_device: null
        sample_rate: 16000
        silence_duration: 320
        min_duration: 70

      post_processing:
        writing_key_press_delay: 0.003
        remove_trailing_period: false
        add_trailing_space: true
        remove_capitalization: false
        input_method: ${inputMethod}

      misc:
        print_to_terminal: true
        hide_status_window: false
        noise_on_completion: true
      '';
    };

    xdg.configFile."voice-input-streaming/config.yaml" = {
      force = true;
      text = ''
      hotkey: ${cfg.hotkey}

      model:
        name: ${cfg.streaming.model}
        device: ${cfg.streaming.device}
        compute_type: ${cfg.streaming.computeType}
        language: ${if cfg.streaming.language == null then "null" else cfg.streaming.language}
        temperature: 0.0
        initial_prompt: "${cfg.streaming.initialPrompt}"
        vad_filter: true

      streaming:
        sample_rate: 16000
        chunk_ms: ${toString cfg.streaming.chunkMs}
        endpoint_ms: ${toString cfg.streaming.endpointMs}
        max_utterance_ms: ${toString cfg.streaming.maxUtteranceMs}

      fallback:
        auto_to_whisper_writer: ${if cfg.fallback.autoToWhisperWriter then "true" else "false"}
      '';
    };

    xdg.configFile."voice-input-sherpa-onnx/config.yaml" = {
      force = true;
      text = ''
      hotkey: ${cfg.hotkey}

      sherpa:
        model: ${cfg.sherpa.model}
        sample_rate: ${toString cfg.sherpa.sampleRate}
        chunk_ms: ${toString cfg.sherpa.chunkMs}
        endpoint_ms: ${toString cfg.sherpa.endpointMs}
        max_utterance_ms: ${toString cfg.sherpa.maxUtteranceMs}
        punctuation_policy: ${cfg.sherpa.punctuationPolicy}
        interaction_mode: ${cfg.sherpa.interactionMode}
        feedback:
          recording_notify: ${if cfg.sherpa.feedback.recordingNotify then "true" else "false"}
          thinking_notify: ${if cfg.sherpa.feedback.thinkingNotify then "true" else "false"}
          done_notify: ${if cfg.sherpa.feedback.doneNotify then "true" else "false"}
          sound:
            enable: ${if cfg.sherpa.feedback.sound.enable then "true" else "false"}
            on_start: ${if cfg.sherpa.feedback.sound.onStart then "true" else "false"}
            on_stop: ${if cfg.sherpa.feedback.sound.onStop then "true" else "false"}
            on_done: ${if cfg.sherpa.feedback.sound.onDone then "true" else "false"}
            theme: ${cfg.sherpa.feedback.sound.theme}

      fallback:
        auto_to_fw_streaming: ${if cfg.fallback.autoToFwStreaming then "true" else "false"}
      '';
    };

    xdg.configFile."voice-input-funasr-nano/config.yaml" = {
      force = true;
      text = ''
      hotkey: ${cfg.hotkey}

      funasr_nano:
        model: ${cfg.funasrNano.model}
        device: ${cfg.funasrNano.device}
        dtype: ${cfg.funasrNano.dtype}
        sample_rate: ${toString cfg.funasrNano.sampleRate}
        chunk_ms: ${toString cfg.funasrNano.chunkMs}
        endpoint_ms: ${toString cfg.funasrNano.endpointMs}
        max_utterance_ms: ${toString cfg.funasrNano.maxUtteranceMs}
        punctuation_policy: ${cfg.funasrNano.punctuationPolicy}
        interaction_mode: ${cfg.funasrNano.interactionMode}
        hotword_boost_enable: ${if cfg.funasrNano.hotwordBoostEnable then "true" else "false"}
        hotword_boost_weight: ${toString cfg.funasrNano.hotwordBoostWeight}
        learning_min_hits: ${toString cfg.funasrNano.learningMinHits}
        auto_learn_enable: ${if cfg.funasrNano.autoLearnEnable then "true" else "false"}
        warmup_on_start: ${if cfg.funasrNano.warmupOnStart then "true" else "false"}
        warmup_blocking_start: ${if cfg.funasrNano.warmupBlockingStart then "true" else "false"}
        torch_num_threads: ${toString cfg.funasrNano.torchNumThreads}
        feedback:
          recording_notify: ${if cfg.funasrNano.feedback.recordingNotify then "true" else "false"}
          thinking_notify: ${if cfg.funasrNano.feedback.thinkingNotify then "true" else "false"}
          done_notify: ${if cfg.funasrNano.feedback.doneNotify then "true" else "false"}
          sound:
            enable: ${if cfg.funasrNano.feedback.sound.enable then "true" else "false"}
            on_start: ${if cfg.funasrNano.feedback.sound.onStart then "true" else "false"}
            on_stop: ${if cfg.funasrNano.feedback.sound.onStop then "true" else "false"}
            on_done: ${if cfg.funasrNano.feedback.sound.onDone then "true" else "false"}
            theme: ${cfg.funasrNano.feedback.sound.theme}

      fallback:
        auto_to_fw_streaming: ${if cfg.fallback.autoToFwStreaming then "true" else "false"}
      '';
    };

    xdg.configFile."voice-input-sherpa-onnx/seed/tech_en.user.words" = {
      source = ./seed/tech_en.user.words;
      force = true;
    };

    xdg.configFile."voice-input-sherpa-onnx/seed/user_corrections.rules" = {
      source = ./seed/user_corrections.rules;
      force = true;
    };

    xdg.configFile."voice-input-sherpa-onnx/seed/auto_corrections.rules" = {
      source = ./seed/auto_corrections.rules;
      force = true;
    };

    xdg.configFile."voice-input-funasr-nano/seed/tech_en.user.words" = {
      source = ./seed/tech_en.user.words;
      force = true;
    };

    xdg.configFile."voice-input-funasr-nano/seed/user_corrections.rules" = {
      source = ./seed/user_corrections.rules;
      force = true;
    };

    xdg.configFile."voice-input-funasr-nano/seed/auto_corrections.rules" = {
      source = ./seed/auto_corrections.rules;
      force = true;
    };

    systemd.user.services.whisper-writer = {
      Unit = {
        Description = "WhisperWriter - local voice dictation";
        After = [ "graphical-session.target" "pipewire.service" ];
        PartOf = [ "graphical-session.target" ];
        Conflicts = [ "voice-input-fw-streaming.service" "voice-input-sherpa-onnx.service" "voice-input-funasr-nano.service" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/whisper-writer";
        Restart = "on-failure";
        RestartSec = 3;
        Environment = [
          "DISPLAY=:0"
          "XAUTHORITY=%h/.Xauthority"
          "HF_HOME=%h/.cache/huggingface"
          "XDG_CACHE_HOME=%h/.cache"
          "WHISPER_WRITER_CONFIG=%h/.config/whisper-writer/config.yaml"
          "QT_QPA_PLATFORM=${if cfg.backend == "auto" then "xcb" else qtPlatform}"
        ];
      };
      Install = lib.mkIf (cfg.autoStart && cfg.engine == "whisper-writer") {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    systemd.user.services.voice-input-fw-streaming = {
      Unit = {
        Description = "Voice Input - faster-whisper streaming";
        After = [ "graphical-session.target" "pipewire.service" ];
        PartOf = [ "graphical-session.target" ];
        Conflicts = [ "whisper-writer.service" "voice-input-sherpa-onnx.service" "voice-input-funasr-nano.service" ];
      };
      Service = {
        ExecStart = "${cfg.streamingPackage}/bin/voice-input-fw-streaming";
        Restart = "on-failure";
        RestartSec = 3;
        Environment = [
          "DISPLAY=:0"
          "XAUTHORITY=%h/.Xauthority"
          "HF_HOME=%h/.cache/huggingface"
          "XDG_CACHE_HOME=%h/.cache"
          "VOICE_INPUT_STREAMING_CONFIG=%h/.config/voice-input-streaming/config.yaml"
          "QT_QPA_PLATFORM=${if cfg.backend == "auto" then "xcb" else qtPlatform}"
        ];
      };
      Install = lib.mkIf (cfg.autoStart && cfg.engine == "fw-streaming") {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    systemd.user.services.voice-input-sherpa-onnx = {
      Unit = {
        Description = "Voice Input - sherpa-onnx";
        After = [ "graphical-session.target" "pipewire.service" ];
        PartOf = [ "graphical-session.target" ];
        Conflicts = [ "whisper-writer.service" "voice-input-fw-streaming.service" "voice-input-funasr-nano.service" ];
      };
      Service = {
        ExecStart = "${cfg.sherpaPackage}/bin/voice-input-sherpa-onnx";
        Restart = "on-failure";
        RestartSec = 3;
        Environment = [
          "DISPLAY=:0"
          "XAUTHORITY=%h/.Xauthority"
          "XDG_CACHE_HOME=%h/.cache"
          "VOICE_INPUT_SHERPA_CONFIG=%h/.config/voice-input-sherpa-onnx/config.yaml"
          "VOICE_INPUT_TECH_WORDS=%h/.local/share/voice-input-sherpa-onnx/lexicons/tech_en.user.words:%h/.config/voice-input-sherpa-onnx/seed/tech_en.user.words:${cfg.sherpaPackage}/share/voice-input-sherpa-onnx/lexicons/tech_en.words"
          "VOICE_INPUT_USER_CORRECTIONS=%h/.local/share/voice-input-sherpa-onnx/lexicons/user_corrections.rules:%h/.config/voice-input-sherpa-onnx/seed/user_corrections.rules"
          "VOICE_INPUT_AUTO_CORRECTIONS=%h/.local/state/voice-input-sherpa-onnx/auto_corrections.rules:%h/.config/voice-input-sherpa-onnx/seed/auto_corrections.rules"
          "VOICE_INPUT_AUTO_CORRECTIONS_WRITE=%h/.local/state/voice-input-sherpa-onnx/auto_corrections.rules"
          "VOICE_INPUT_AUTO_LEARNING_STATE=%h/.local/state/voice-input-sherpa-onnx/auto_learning.json"
          "VOICE_INPUT_HISTORY_PATH=%h/.local/state/voice-input-sherpa-onnx/history.jsonl"
          "QT_QPA_PLATFORM=${if cfg.backend == "auto" then "xcb" else qtPlatform}"
        ];
      };
      Install = lib.mkIf (cfg.autoStart && cfg.engine == "sherpa-onnx") {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    systemd.user.services.voice-input-funasr-nano = {
      Unit = {
        Description = "Voice Input - funasr-nano";
        After = [ "graphical-session.target" "pipewire.service" ];
        PartOf = [ "graphical-session.target" ];
        Conflicts = [ "whisper-writer.service" "voice-input-fw-streaming.service" "voice-input-sherpa-onnx.service" ];
      };
      Service = {
        ExecStart = "${cfg.funasrNanoPackage}/bin/voice-input-funasr-nano";
        Restart = "on-failure";
        RestartSec = 3;
        Environment = [
          "DISPLAY=:0"
          "XAUTHORITY=%h/.Xauthority"
          "HF_HOME=%h/.cache/huggingface"
          "XDG_CACHE_HOME=%h/.cache"
          "VOICE_INPUT_FUNASR_NANO_CONFIG=%h/.config/voice-input-funasr-nano/config.yaml"
          "VOICE_INPUT_TECH_WORDS=%h/.local/share/voice-input-funasr-nano/lexicons/tech_en.user.words:%h/.config/voice-input-funasr-nano/seed/tech_en.user.words:${cfg.funasrNanoPackage}/share/voice-input-funasr-nano/lexicons/tech_en.words"
          "VOICE_INPUT_USER_CORRECTIONS=%h/.local/share/voice-input-funasr-nano/lexicons/user_corrections.rules:%h/.config/voice-input-funasr-nano/seed/user_corrections.rules"
          "VOICE_INPUT_AUTO_CORRECTIONS=%h/.local/state/voice-input-funasr-nano/auto_corrections.rules:%h/.config/voice-input-funasr-nano/seed/auto_corrections.rules"
          "VOICE_INPUT_AUTO_CORRECTIONS_WRITE=%h/.local/state/voice-input-funasr-nano/auto_corrections.rules"
          "VOICE_INPUT_AUTO_LEARNING_STATE=%h/.local/state/voice-input-funasr-nano/auto_learning.json"
          "VOICE_INPUT_HISTORY_PATH=%h/.local/state/voice-input-funasr-nano/history.jsonl"
          "QT_QPA_PLATFORM=${if cfg.backend == "auto" then "xcb" else qtPlatform}"
        ];
      };
      Install = lib.mkIf (cfg.autoStart && cfg.engine == "funasr-nano") {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
