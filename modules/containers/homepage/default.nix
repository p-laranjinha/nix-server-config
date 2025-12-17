{
  vars,
  funcs,
  config,
  lib,
  ...
}: let
  localVars = vars.containers.containers;

  homepageImage = "ghcr.io/gethomepage/homepage:v1.8.0";
  socketProxyImage = "ghcr.io/tecnativa/docker-socket-proxy:v0.4.1";

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
          homepage = funcs.containers.mkConfig "node" localVars.homepage {
            autoStart = config.opts.containers.homepage.autoStart;
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
            };
          };
          # https://gethomepage.dev/configs/docker/
          # As directly exposing the podman/docker socket to homepage is a
          #  security concern, I'll use this proxy so theres an extra layer
          #  in between that is more controllable and accessable via an API.
          # WARN: Don't publish ports and directly expose this to the internet,
          #  just use container networks or there's no point in using it.
          socket-proxy = funcs.containers.mkConfig "root" localVars.socket-proxy {
            containerConfig = {
              image = socketProxyImage;
              environments = {
                CONTAINERS = "1";
              };
              volumes = [
                # WARN: You may need to reboot for 'podman.sock' to be created.
                #  Or run `systemctl --user start podman.socket`.
                "/run/user/1000/podman/podman.sock:/var/run/docker.sock:ro"
              ];
              networks = ["homepage"];
              dropCapabilities = vars.containers.rootCapabilities;
            };
          };
        };
        networks.homepage = {};
      };
    };
  };
}
