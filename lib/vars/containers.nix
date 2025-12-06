vars: {
  containers = {
    # How many uids and gids the containers will have allocated to them.
    # Will map from 0-1999. More than enough for most containers.
    uidGidCount = 2000;
    # The groups defined in 'groups' start with this gid.
    startGid = 1001;
    groups = [
      "searxng"
      "searxng-valkey"
      "homepage"
      "caddy"
      # "public" # For everything that may be exposed to the internet.
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
      caddy = {
        n = 3;
        mainGroup = "caddy";
        groups = [];
      };
    };
    dataDir = "${vars.homeDirectory}/container-data";
    rootCapabilities = ["CHOWN" "DAC_OVERRIDE" "FOWNER" "FSETID" "KILL" "NET_BIND_SERVICE" "SETFCAP" "SETGID" "SETPCAP" "SETUID" "SYS_CHROOT"];
  };
}
