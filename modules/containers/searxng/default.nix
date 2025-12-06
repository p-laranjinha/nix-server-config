{
  config,
  vars,
  funcs,
  ...
}: let
  searxng-config = funcs.relativeToAbsoluteConfigPath ./config;
  searxng-data = "${vars.containers.dataDir}/searxng/data";
  valkey-data = "${vars.containers.dataDir}/searxng/valkey-data";
in {
  systemd.tmpfiles.rules = [
    "d ${searxng-config} 2770 ${vars.username} ${vars.containers.containers.searxng.mainGroup} - -"
    "d ${vars.containers.dataDir}/searxng 2770 ${vars.username} ${vars.containers.containers.searxng.mainGroup} - -"
    "d ${searxng-data} 2770 ${vars.username} ${vars.containers.containers.searxng.mainGroup} - -"
    "d ${valkey-data} 2770 ${vars.username} ${vars.containers.containers.searxng-valkey.mainGroup} - -"
  ];
  secrets.searxng = {
    sopsFile = ./secrets.env;
    format = "dotenv";
    # Entire file.
    key = "";
    # Only the user can read and nothing else.
    mode = "0400";
    owner = vars.username;
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
            networks = ["searxng-internal" "searxng"];
            user = funcs.containers.mkUser "searxng" vars.containers.containers.searxng.mainGroup;
            uidMaps =
              funcs.containers.mkUidMaps
              vars.containers.containers.searxng.n;
            gidMaps =
              funcs.containers.mkGidMaps
              vars.containers.containers.searxng.n
              ([vars.containers.containers.searxng.mainGroup] ++ vars.containers.containers.searxng.groups);
            addGroups =
              funcs.containers.mkAddGroups
              vars.containers.containers.searxng.groups;
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
            networks = ["searxng-internal"];
            user = funcs.containers.mkUser "valkey" vars.containers.containers.searxng-valkey.mainGroup;
            uidMaps =
              funcs.containers.mkUidMaps
              vars.containers.containers.searxng-valkey.n;
            gidMaps =
              funcs.containers.mkGidMaps
              vars.containers.containers.searxng-valkey.n
              ([vars.containers.containers.searxng-valkey.mainGroup] ++ vars.containers.containers.searxng-valkey.groups);
            addGroups =
              funcs.containers.mkAddGroups
              vars.containers.containers.searxng-valkey.groups;
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
        searxng-internal = {};
      };
    };
  };
}
