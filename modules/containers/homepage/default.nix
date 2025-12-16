{
  vars,
  funcs,
  config,
  lib,
  ...
}: let
  localVars = vars.containers.containers;

  homepageImage = "ghcr.io/gethomepage/homepage:v1.8.0@sha256:7dc099d5c6ec7fc945d858218565925b01ff8a60bcbfda990fc680a8b5cd0b6e";
  socketProxyImage = "ghcr.io/tecnativa/docker-socket-proxy:v0.4.1@sha256:3400c429c5f9e1b21d62130fb93b16e2e772d4fb7695bd52fc2b743800b9fe9e";

  configDir = funcs.relativeToAbsoluteConfigPath ./config;
in {
  options.opts.containers.homepage = {
    enable = lib.mkEnableOption "homepage";
    autoStart = lib.mkEnableOption "homepage auto-start";
  };

  config = lib.mkIf config.opts.containers.homepage.enable {
    systemd.tmpfiles.rules = [
      "d ${configDir} 2770 ${vars.username} ${localVars.homepage.mainGroup} - -"
      "Z ${configDir} 2770 ${vars.username} ${localVars.homepage.mainGroup} - -"
    ];
    # Required to run homepage in rootless mode and it being able to read containers.
    users.users.${vars.username}.extraGroups = ["podman"];
    networking.firewall.allowedTCPPorts = [3000];
    hm = {
      virtualisation.quadlet = {
        containers = {
          homepage = {
            autoStart = config.opts.containers.homepage.autoStart;
            serviceConfig = {
              RestartSec = "10";
              Restart = "always";
            };
            unitConfig = {
              Requires = "socket-proxy.container";
            };
            containerConfig = {
              image = homepageImage;
              publishPorts = ["3000:3000"];
              environments = {
                HOMEPAGE_ALLOWED_HOSTS = "192.168.1.4:3000,server:3000";
              };
              volumes = [
                "${configDir}:/app/config"
              ];
              networks = ["homepage"];
              user = funcs.containers.mkUser "node" localVars.homepage.mainGroup;
              uidMaps = funcs.containers.mkUidMaps localVars.homepage.i;
              gidMaps =
                funcs.containers.mkGidMaps
                localVars.homepage.i
                ([localVars.homepage.mainGroup] ++ localVars.homepage.extraGroups);
              addGroups =
                funcs.containers.mkAddGroups
                localVars.homepage.extraGroups;
            };
          };
          # https://gethomepage.dev/configs/docker/
          # As directly exposing the podman/docker socket to homepage is a
          #  security concern, I'll use this proxy so theres an extra layer
          #  in between that is more controllable and accessable via an API.
          # WARN: Don't publish ports and directly expose this to the internet,
          #  just use container networks or there's no point in using it.
          socket-proxy = {
            autoStart = false;
            serviceConfig = {
              RestartSec = "10";
              Restart = "always";
            };
            containerConfig = {
              image = socketProxyImage;
              environments = {
                CONTAINERS = "1";
              };
              volumes = [
                "/run/user/1000/podman/podman.sock:/var/run/docker.sock:ro"
              ];
              networks = ["homepage"];
              user = funcs.containers.mkUser "root" localVars.socket-proxy.mainGroup;
              uidMaps = funcs.containers.mkUidMaps localVars.socket-proxy.i;
              gidMaps =
                (funcs.containers.mkGidMaps
                  localVars.socket-proxy.i
                  ([localVars.socket-proxy.mainGroup] ++ localVars.socket-proxy.extraGroups))
                # Map 'users' to '9999'.
                ++ ["9999:0:1"];
              addGroups =
                (funcs.containers.mkAddGroups
                  localVars.socket-proxy.extraGroups)
                # Add the 'users' group to the container user.
                ++ ["9999"];
            };
          };
        };
        networks.homepage = {};
      };
    };
  };
}
