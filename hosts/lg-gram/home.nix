{ config, pkgs, ... }:
{
  xdg.configFile."easyeffects/output/lg-gram-safe.json".text = ''
    {
      "output": {
        "blocklist": [],
        "stereo_tools#0": {
          "bypass": false,
          "input-gain": 0.0,
          "output-gain": 0.0,
          "balance-in": 0.0,
          "balance-out": 0.0,
          "softclip": false,
          "mutel": false,
          "muter": false,
          "phasel": false,
          "phaser": false,
          "mode": "LR > LR (Stereo Default)",
          "slev": 0.0,
          "sbal": 0.0,
          "mlev": 0.0,
          "mpan": 0.0,
          "stereo-base": 0.15,
          "delay": 0.0,
          "sc-level": 1.0,
          "stereo-phase": 0.0,
          "dry": -100.0,
          "wet": 0.0
        },
        "bass_enhancer#0": {
          "bypass": false,
          "input-gain": 0.0,
          "output-gain": 0.0,
          "amount": 2.0,
          "harmonics": 8.5,
          "scope": 100.0,
          "floor": 20.0,
          "blend": 0.0,
          "floor-active": true,
          "listen": false
        },
        "plugins_order": [
          "stereo_tools#0",
          "bass_enhancer#0"
        ]
      }
    }
  '';

  systemd.user.services.easyeffects = {
    Unit = {
      Description = "EasyEffects audio effects";
      After = [ "pipewire.service" "wireplumber.service" ];
    };
    Service = {
      ExecStart = "${pkgs.easyeffects}/bin/easyeffects --gapplication-service";
      ExecStartPost = "${pkgs.easyeffects}/bin/easyeffects -l lg-gram-safe";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.chrome-cleanup = {
    Unit = {
      Description = "Remove stale Google Chrome singleton locks";
      After = [ "graphical-session-pre.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = ''${pkgs.bash}/bin/bash -c "${pkgs.coreutils}/bin/rm -f \"$HOME/.config/google-chrome/SingletonLock\" \"$HOME/.config/google-chrome/SingletonCookie\" \"$HOME/.config/google-chrome/SingletonSocket\""'';
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services."touchpad-natural-scroll" = let
    script = pkgs.writeShellScript "enable-natural-scroll" ''
      set -euo pipefail
      if [ -z "${DISPLAY:-}" ]; then
        export DISPLAY=:0
      fi
      if [ -z "${XAUTHORITY:-}" ]; then
        export XAUTHORITY="$HOME/.Xauthority"
      fi
      device=$(${pkgs.xorg.xinput}/bin/xinput list --name-only | ${pkgs.gnugrep}/bin/grep -i "touchpad" | ${pkgs.coreutils}/bin/head -n1 || true)
      if [ -n "$device" ]; then
        ${pkgs.xorg.xinput}/bin/xinput set-prop "$device" "libinput Natural Scrolling Enabled" 1 || true
      fi
    '';
  in {
    Unit = {
      Description = "Ensure touchpad natural scrolling is enabled";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = script;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
