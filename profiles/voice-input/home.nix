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
      type = lib.types.enum [ "whisper-writer" "fw-streaming" "sherpa-onnx" ];
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
        description = "Auto fallback to fw-streaming when sherpa startup fails.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      cfg.streamingPackage
      cfg.sherpaPackage
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

      fallback:
        auto_to_fw_streaming: ${if cfg.fallback.autoToFwStreaming then "true" else "false"}
      '';
    };

    systemd.user.services.whisper-writer = {
      Unit = {
        Description = "WhisperWriter - local voice dictation";
        After = [ "graphical-session.target" "pipewire.service" ];
        PartOf = [ "graphical-session.target" ];
        Conflicts = [ "voice-input-fw-streaming.service" "voice-input-sherpa-onnx.service" ];
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
        Conflicts = [ "whisper-writer.service" "voice-input-sherpa-onnx.service" ];
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
        Conflicts = [ "whisper-writer.service" "voice-input-fw-streaming.service" ];
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
          "VOICE_INPUT_TECH_WORDS=%h/.local/share/voice-input-sherpa-onnx/lexicons/tech_en.user.words:${cfg.sherpaPackage}/share/voice-input-sherpa-onnx/lexicons/tech_en.words"
          "VOICE_INPUT_USER_CORRECTIONS=%h/.local/share/voice-input-sherpa-onnx/lexicons/user_corrections.rules"
          "VOICE_INPUT_AUTO_CORRECTIONS=%h/.local/state/voice-input-sherpa-onnx/auto_corrections.rules"
          "VOICE_INPUT_AUTO_LEARNING_STATE=%h/.local/state/voice-input-sherpa-onnx/auto_learning.json"
          "VOICE_INPUT_HISTORY_PATH=%h/.local/state/voice-input-sherpa-onnx/history.jsonl"
          "QT_QPA_PLATFORM=${if cfg.backend == "auto" then "xcb" else qtPlatform}"
        ];
      };
      Install = lib.mkIf (cfg.autoStart && cfg.engine == "sherpa-onnx") {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
