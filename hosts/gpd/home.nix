{ config, pkgs, ... }:

{
  systemd.user.services.hyprland-auto-rotate = {
    Unit = {
      Description = "Auto rotate Hyprland display and touch input from accelerometer";
      PartOf = [ "hyprland-session.target" ];
      After = [ "hyprland-session.target" ];
    };
    Service = {
      Type = "simple";
      Restart = "always";
      RestartSec = 2;
      ExecStart = pkgs.writeShellScript "hyprland-auto-rotate" ''
        set -euo pipefail

        HYPRCTL="${pkgs.hyprland}/bin/hyprctl"
        JQ="${pkgs.jq}/bin/jq"
        MONITOR_SENSOR="${pkgs.iio-sensor-proxy}/bin/monitor-sensor"
        SLEEP="${pkgs.coreutils}/bin/sleep"

        # Wait until Hyprland IPC is ready.
        for _ in $("${pkgs.coreutils}/bin/seq" 1 40); do
          if [ -S "''${XDG_RUNTIME_DIR}/hypr/''${HYPRLAND_INSTANCE_SIGNATURE}/.socket.sock" ]; then
            break
          fi
          "$SLEEP" 0.25
        done

        get_monitor() {
          "$HYPRCTL" -j monitors 2>/dev/null | "$JQ" -r '
            (.[] | select(.focused == true) | .name),
            (.[] | select(.id == 0) | .name),
            (.[0].name)
          ' | "${pkgs.coreutils}/bin/head" -n1
        }

        get_monitor_scale() {
          local monitor="$1"
          "$HYPRCTL" -j monitors 2>/dev/null | "$JQ" -r --arg monitor "$monitor" '
            (.[] | select(.name == $monitor) | .scale) // 1
          ' | "${pkgs.coreutils}/bin/head" -n1
        }

        apply_transform() {
          local transform="$1"
          local monitor
          monitor="$(get_monitor)"
          [ -n "$monitor" ] || return 0

          local scale
          scale="$(get_monitor_scale "$monitor")"
          [ -n "$scale" ] || scale="1"

          "$HYPRCTL" keyword monitor "$monitor,preferred,auto,$scale,transform,$transform" >/dev/null 2>&1 || true

          "$HYPRCTL" -j devices 2>/dev/null | "$JQ" -r '
            ((.touch // []) + (.touchDevices // []))[]?.name
          ' | while IFS= read -r dev; do
            [ -n "$dev" ] || continue
            "$HYPRCTL" keyword "device[$dev]:transform" "$transform" >/dev/null 2>&1 || true
          done
        }

        orientation_to_transform() {
          case "$1" in
            # GPD natural usage is landscape (keyboard at the bottom when opened),
            # so apply a calibrated offset from iio-sensor-proxy orientation.
            normal) echo 3 ;;
            left-up) echo 0 ;;
            right-up) echo 2 ;;
            bottom-up) echo 1 ;;
            *) return 1 ;;
          esac
        }

        "$MONITOR_SENSOR" | while IFS= read -r line; do
          case "$line" in
            *"Accelerometer orientation changed:"*)
              orientation="$(${pkgs.gnused}/bin/sed -E 's/.*changed: *([^ ]+).*/\1/' <<<"$line")"
              if transform="$(orientation_to_transform "$orientation")"; then
                apply_transform "$transform"
              fi
              ;;
          esac
        done
      '';
    };
    Install = {
      WantedBy = [ "hyprland-session.target" ];
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
