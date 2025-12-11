vars: {
  containers = {
    # How many uids and gids the containers will have allocated to them.
    # Will map from 0-1999. More than enough for most containers.
    uidGidCount = 2000;
    # The groups defined in 'groups' start with this gid.
    startGid = 1001;
    # WARNING: When replacing a group, first remove the old one and the
    #  containers that use it, rebuild, add the new one, then rebuild again.
    groups = [
      "searxng"
      "searxng-valkey"
      "homepage"
      "blocky" # Container doesn't seem to use groups, but I'll leave it for now.
      "public" # For everything that may be exposed to the internet.
      "copyparty"
      # "caddy"
    ];
    containers = {
      searxng = {
        n = 0;
        mainGroup = "searxng";
        groups = [];
      };
      searxng-valkey = {
        n = 1;
        mainGroup = "searxng-valkey";
        groups = [];
      };
      homepage = {
        n = 2;
        mainGroup = "homepage";
        groups = [];
      };
      blocky = {
        n = 3;
        mainGroup = "blocky";
        groups = [];
      };
      copyparty = {
        n = 4;
        mainGroup = "copyparty";
        groups = [];
      };
      # ISSUE: Add a secondary DNS to the router when messing with containers
      #  as if pihole is down as the only DNS, there is no internet.

      # caddy = {
      #   n = 3;
      #   mainGroup = "caddy";
      #   groups = [];
      # };
    };
    dataDir = "${vars.homeDirectory}/container-data";
    publicDir = "${vars.homeDirectory}/public";
    rootCapabilities = ["CHOWN" "DAC_OVERRIDE" "FOWNER" "FSETID" "KILL" "NET_BIND_SERVICE" "SETFCAP" "SETGID" "SETPCAP" "SETUID" "SYS_CHROOT"];
  };
}
