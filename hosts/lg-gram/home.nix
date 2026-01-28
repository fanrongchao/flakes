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

}
