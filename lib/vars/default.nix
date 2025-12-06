inputs: let
  # Setting this in 'let in' so the values can be used easier in imports.
  default = rec {
    hostname = "server";
    username = "pebble";
    fullname = "Orange Pebble";
    homeDirectory = "/home/pebble";
    configDirectory = "${homeDirectory}/nix-server-config";
    secretsDirectory = "${inputs.self}/secrets";
    hostPlatform = "x86_64-linux";
    # Research properly before changing this.
    stateVersion = "24.05";
  };
  containers = import ./containers.nix default;
in
  default // containers
