{ config, lib, pkgs, ... }:
{
  options.aiInference.vllmMinimaxM2Awq.enable = lib.mkEnableOption "vLLM MiniMax-M2.1-AWQ service";

  config = lib.mkIf config.aiInference.vllmMinimaxM2Awq.enable {
    sops.age.keyFile = "/var/lib/sops/age/keys.txt";
    sops.secrets."vllm/minimax/api_key" = {
      sopsFile = ../../secrets/ai-inference.yaml;
      owner = "xfa";
      group = "users";
      mode = "0400";
    };
    systemd.tmpfiles.rules = [
      "L+ /sbin/ldconfig - - - - /run/current-system/sw/sbin/ldconfig"
    ];

    systemd.services.vllm-minimax-m2-awq = {
    description = "vLLM MiniMax-M2.1-AWQ";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    path = with pkgs; [
      bash
      coreutils
      findutils
      gnugrep
      gnused
      python312
    ];

    serviceConfig = {
      Type = "simple";
      User = "xfa";
      Group = "users";
      WorkingDirectory = "/home/xfa/ai/minimax-m2.1-awq";
      Restart = "always";
      RestartSec = 15;
      LimitNOFILE = 1048576;
      Environment = [
        "HF_HOME=/home/xfa/.cache/huggingface"
        "VLLM_USE_DEEP_GEMM=0"
        "VLLM_USE_FLASHINFER_MOE_FP16=1"
        "VLLM_USE_FLASHINFER_SAMPLER=0"
        "OMP_NUM_THREADS=4"
        "SAFETENSORS_FAST_GPU=1"
        "LD_LIBRARY_PATH=/run/opengl-driver/lib:${pkgs.stdenv.cc.cc.lib}/lib"
      ];
    };

    script = ''
      set -euo pipefail

      APP_DIR="/home/xfa/ai/minimax-m2.1-awq"
      MODEL_DIR="/home/xfa/ai/models/MiniMax-M2.1-AWQ"
      VENV_DIR="$APP_DIR/.venv"

      mkdir -p "$APP_DIR" "$MODEL_DIR"

      if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
      fi

      source "$VENV_DIR/bin/activate"

      if ! python -c 'import vllm; assert vllm.__version__ == "0.13.0"' >/dev/null 2>&1; then
        python -m pip install -U pip
        python -m pip install -U "vllm==0.13.0" "huggingface_hub[cli]"
      fi

      VLLM_API_KEY="$(cat "${config.sops.secrets."vllm/minimax/api_key".path}")"
      hf download QuantTrio/MiniMax-M2.1-AWQ --local-dir "$MODEL_DIR"

      exec vllm serve "$MODEL_DIR" \
        --served-model-name MiniMax-M2.1-AWQ \
        --api-key "$VLLM_API_KEY" \
        --swap-space 16 \
        --max-num-seqs 32 \
        --max-model-len 32768 \
        --gpu-memory-utilization 0.9 \
        --tensor-parallel-size 8 \
        --enable-expert-parallel \
        --enable-auto-tool-choice \
        --tool-call-parser minimax_m2 \
        --reasoning-parser minimax_m2_append_think \
        --trust-remote-code \
        --host 127.0.0.1 \
        --port 8000
    '';
    };
  };
}
