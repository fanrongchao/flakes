{ pkgs, self, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  networking.hostName = "m5-air";
  networking.localHostName = "m5-air";
  networking.computerName = "m5-air";

  users.users.frc = {
    home = "/Users/frc";
    shell = pkgs.zsh;
  };

  security.sudo.extraConfig = ''
    frc ALL=(ALL) NOPASSWD: ALL
  '';

  system.primaryUser = "frc";

  programs.zsh.enable = true;
  environment.systemPackages = with pkgs; [
    git
  ];

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;
}
