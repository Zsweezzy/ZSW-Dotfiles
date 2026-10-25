{ pkgs, ... }:
let
  wl-paste = "${pkgs.wl-clipboard}/bin/wl-paste";
  cliphist = "${pkgs.cliphist}/bin/cliphist";
  # These lived in hyprland.lua as exec_cmd lines; as units they survive
  # Hyprland restarts. PassEnvironment mirrors what the session provides.
  sessionEnv = [ "WAYLAND_DISPLAY" "XDG_RUNTIME_DIR" ];
in
{
  # Clipboard history daemon: store text + image selections.
  systemd.user.services.cliphist-text = {
    Unit = {
      Description = "cliphist: watch text clipboard";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${wl-paste} --type text --watch ${cliphist} store";
      Restart = "always";
      PassEnvironment = sessionEnv;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.cliphist-image = {
    Unit = {
      Description = "cliphist: watch image clipboard";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${wl-paste} --type image --watch ${cliphist} store";
      Restart = "always";
      PassEnvironment = sessionEnv;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Was an unmanaged ~/.config/systemd/user/shadowclip.service
  # (backup: ~/Backups/shadowclip.service.bak-2026-10-17).
  systemd.user.services.shadowclip = {
    Unit = {
      Description = "shadowclip game clip recorder";
      After = [ "graphical-session.target" ];
      StartLimitIntervalSec = 60;
      StartLimitBurst = 3;
    };
    Service = {
      ExecStart = "%h/.local/bin/shadowclip gui";
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 3;
      PassEnvironment = [
        "WAYLAND_DISPLAY"
        "DISPLAY"
        "XDG_RUNTIME_DIR"
        "DBUS_SESSION_BUS_ADDRESS"
        "XDG_SESSION_TYPE"
        "XDG_CURRENT_DESKTOP"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" "default.target" ];
  };
}
