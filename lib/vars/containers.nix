vars: let
  containers = {
    # How many uids and gids the containers will have allocated to them.
    # Will map from 0-1999. More than enough for most containers.
    uidGidCount = 2000;
    # The groups defined in 'groups' start with this gid.
    startGid = 1001;
    # Not all containers need special groups because they don't use volumes,
    #  but I'll add them just in case.
    groups = [
      "public" # For everything that may be exposed to the internet.
      "searxng"
      "searxng-valkey"
      "homepage"
      "blocky" # TODO: remove
      "copyparty"
      "immich"
      "immich-machine-learning"
      "immich-database"
      "socket-proxy" # TODO: remove
      "immich-redis" # TODO: remove
    ];
    # Unfortunately, I need to make this a list if I want to keep the order in
    #  the modifying function below. If I used an attrset, they would be sorted
    #  alphabetically and so the subuid and subgid used aren't fixed.
    containers = [
      {searxng.mainGroup = "searxng";}
      {searxng-valkey.mainGroup = "searxng-valkey";}
      {homepage.mainGroup = "homepage";}
      {blocky.mainGroup = "blocky";}
      # {socket-proxy.mainGroup = "users";}
      {socket-proxy.mainGroup = "socket-proxy";}
      {
        copyparty = {
          mainGroup = "copyparty";
          extraGroups = ["public"];
        };
      }
      {
        immich = {
          mainGroup = "immich";
          extraGroups = ["public"];
        };
      }
      {immich-machine-learning.mainGroup = "immich-machine-learning";}
      # {immich-redis = {};}
      {immich-redis.mainGroup = "immich-redis";}
      {immich-database.mainGroup = "immich-database";}
      # ISSUE: Add a secondary DNS to the router when messing with containers
      #  as if pihole is down as the only DNS, there is no internet.
    ];
    dataDir = "${vars.homeDirectory}/container-data";
    publicDir = "${vars.homeDirectory}/public";
    rootCapabilities = ["CHOWN" "DAC_OVERRIDE" "FOWNER" "FSETID" "KILL" "NET_BIND_SERVICE" "SETFCAP" "SETGID" "SETPCAP" "SETUID" "SYS_CHROOT"];
  };
in {
  containers = with builtins;
    mapAttrs (name: value:
      if name == "containers"
      then
        listToAttrs (genList (
          i: let
            containerName = elemAt (attrNames (elemAt value i)) 0;
            containerValue = (elemAt value i).${containerName};
          in {
            name = containerName;
            value = {
              i = i;
              mainGroup = containerValue.mainGroup or null;
              extraGroups = containerValue.groups or [];
            };
          }
        ) (length value))
      else value)
    containers;
}
