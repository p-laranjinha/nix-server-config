{
  this,
  config,
  ...
}: let
  vars =
    config.vars.containers
    // {dataDir = config.vars.containerDataDir;};
  funcs = config.funcs.containers;
  searxng-config = config.lib.meta.relativeToAbsoluteConfigPath ./config;
  searxng-data = "${vars.dataDir}/searxng/data";
  valkey-data = "${vars.dataDir}/searxng/valkey-data";
in {
  systemd.tmpfiles.rules = [
    "d ${searxng-config} 2770 ${this.username} ${vars.searxng.mainGroup} - -"
    "d ${vars.dataDir}/searxng - ${this.username} - - -"
    "d ${searxng-data} 2770 ${this.username} ${vars.searxng.mainGroup} - -"
    "d ${valkey-data} 2770 ${this.username} ${vars.searxng-valkey.mainGroup} - -"
  ];
  secrets.searxng = {
    sopsFile = ./secrets.env;
    format = "dotenv";
    # Entire file.
    key = "";
    # Only the user can read and nothing else.
    mode = "0400";
    owner = this.username;
  };
  networking.firewall.allowedTCPPorts = [8080];
  hm = {
    # https://seiarotg.github.io/quadlet-nix/home-manager-options.html
    virtualisation.quadlet = {
      containers = {
        searxng = {
          autoStart = true;
          serviceConfig = {
            RestartSec = "10";
            Restart = "always";
          };
          containerConfig = {
            image = "docker.io/searxng/searxng:latest";
            publishPorts = ["8080:8080"];
            environments = {
              FORCE_OWNERSHIP = "false";
            };
            environmentFiles = [config.secrets.searxng.path];
            volumes = [
              "${searxng-config}:/etc/searxng"
              "${searxng-data}:/var/cache/searxng"
            ];
            networks = ["searxng"];
            user = funcs.mkUser "searxng" vars.searxng.mainGroup;
            uidMaps =
              funcs.mkUidMaps
              vars.searxng.n;
            gidMaps =
              funcs.mkGidMaps
              vars.searxng.n
              ([vars.searxng.mainGroup] ++ vars.searxng.groups);
            addGroups =
              funcs.mkAddGroups
              vars.searxng.groups;
          };
        };
        searxng-valkey = {
          autoStart = true;
          serviceConfig = {
            RestartSec = "10";
            Restart = "always";
          };
          containerConfig = {
            image = "docker.io/valkey/valkey:latest";
            exec = "valkey-server --save 30 1 --loglevel warning";
            volumes = ["${valkey-data}:/data"];
            networkAliases = ["valkey"];
            networks = ["searxng"];
            user = funcs.mkUser "valkey" vars.searxng-valkey.mainGroup;
            uidMaps =
              funcs.mkUidMaps
              vars.searxng-valkey.n;
            gidMaps =
              funcs.mkGidMaps
              vars.searxng-valkey.n
              ([vars.searxng-valkey.mainGroup] ++ vars.searxng-valkey.groups);
            addGroups =
              funcs.mkAddGroups
              vars.searxng-valkey.groups;
          };
        };
        # https://github.com/searx/searx/discussions/1723#discussioncomment-832494
        # searxng-tor = {
        #   autoStart = true;
        #   serviceConfig = {
        #     RestartSec = "10";
        #     Restart = "always";
        #   };
        #   containerConfig = {
        #     image = "docker.io/osminogin/tor-simple:latest";
        #     networkAliases = [
        #       "tor"
        #     ];
        #     networks = [
        #       "searxng"
        #     ];
        #     userns = "keep-id";
        #   };
        # };
      };
      networks = {
        searxng = {};
      };
    };
  };
}
