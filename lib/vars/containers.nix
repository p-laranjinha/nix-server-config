vars: {
  containers = {
    # How many uids and gids the containers will have allocated to them.
    # Will map from 0-1999. More than enough for most containers.
    uidGidCount = 2000;
    # The groups defined in 'groups' start with this gid.
    startGid = 1001;
    # Not all containers need special groups because they don't use volumes,
    #  but I'll add them just in case.
    groups = [
      "searxng"
      "searxng-valkey"
      "homepage"
      "blocky"
      "public" # For everything that may be exposed to the internet.
      "copyparty"
      "immich-server"
      "immich-machine-learning"
      "immich-redis"
      "immich-database"
      "socket-proxy"
      # WARNING: When replacing a group, first remove the old one and the
      #  containers that use it, rebuild, add the new one, then rebuild again.
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
        groups = ["public"];
      };
      immich-server = {
        n = 5;
        mainGroup = "immich-server";
        groups = ["public"];
      };
      immich-machine-learning = {
        n = 6;
        mainGroup = "immich-machine-learning";
        groups = [];
      };
      immich-redis = {
        n = 7;
        mainGroup = "immich-redis";
        groups = [];
      };
      immich-database = {
        n = 8;
        mainGroup = "immich-database";
        groups = [];
      };
      socket-proxy = {
        n = 9;
        mainGroup = "socket-proxy";
        groups = [];
      };
      # ISSUE: Add a secondary DNS to the router when messing with containers
      #  as if pihole is down as the only DNS, there is no internet.
    };
    dataDir = "${vars.homeDirectory}/container-data";
    publicDir = "${vars.homeDirectory}/public";
    rootCapabilities = ["CHOWN" "DAC_OVERRIDE" "FOWNER" "FSETID" "KILL" "NET_BIND_SERVICE" "SETFCAP" "SETGID" "SETPCAP" "SETUID" "SYS_CHROOT"];
  };
}
