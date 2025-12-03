{
  inputs,
  pkgs,
  this,
  config,
  ...
}: {
  networking.hostName = this.hostname;
  # Obtained via `head -c 8 /etc/machine-id`, might require manually mounting
  #  /home on first boot.
  networking.hostId = "59718dc4";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.pebble = {
    isNormalUser = true;
    description = this.fullname;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
    hashedPasswordFile = config.secrets.password.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIZeqsx4YGlynKAgAW/kFvcdb3Ec4ES+b+j8eZuQ6l2 pebble@orange"
    ];
  };
  secrets.password = {
    sopsFile = ../secrets/password;
    format = "binary";
    # Entire file.
    key = "";
    # Only the user can read and nothing else.
    mode = "0400";
    owner = this.username;
    neededForUsers = true;
  };

  security.sudo.extraConfig = ''
    Defaults pwfeedback # Shows asterisks when typing password.
  '';

  # Sets the configuration revision string to either the git commit reference or 'dirty'.
  # Can be seen on entries shown by 'nixos-rebuild list-generations'.
  system.configurationRevision = inputs.self.rev or "dirty";

  nix.settings.experimental-features = ["nix-command" "flakes"];

  nix.optimise = {
    # Cleans the store
    automatic = true;
    dates = ["weekly"];
  };
  nix.gc = {
    # Deletes old generations
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Adds current flake to the registry so it can be accessed in things like the repl.
  nix.registry.config.flake = inputs.self;

  services.openssh = {
    enable = true;
    ports = [22];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      TCPKeepAlive = "yes";
      AllowUsers = ["pebble"];
    };
  };
  services.fail2ban.enable = true;

  networking.interfaces.enp9s0.wakeOnLan.enable = true;

  services.tailscale.enable = true;

  system.stateVersion = this.stateVersion;
}
