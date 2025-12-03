{
  this,
  config,
  ...
}: let
  vars =
    config.vars.containers.caddy
    // {
      dataDir = config.vars.containerDataDir;
      rootCapabilities = config.vars.rootCapabilities;
    };
  funcs = config.funcs.containers;
  caddy-config = config.lib.meta.relativeToAbsoluteConfigPath ./config;
  # Directory to serve static files from.
  caddy-site = config.lib.meta.relativeToAbsoluteConfigPath ./site;
  caddy-data = "${vars.dataDir}/caddy/data";
  caddy-data-config = "${vars.dataDir}/caddy/config";
in {
  systemd.tmpfiles.rules = [
    "d ${caddy-config} 2770 ${this.username} ${vars.mainGroup} - -"
    "d ${caddy-site} 2770 ${this.username} ${vars.mainGroup} - -"
    "d ${vars.dataDir}/caddy 2770 ${this.username} ${vars.mainGroup} - -"
    "d ${caddy-data} 2770 ${this.username} ${vars.mainGroup} - -"
    "d ${caddy-data-config} 2770 ${this.username} ${vars.mainGroup} - -"
  ];
  # Allow non-root users to bind to privileged ports like 80.
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
  networking.firewall.allowedTCPPorts = [80 443];
  networking.firewall.allowedUDPPorts = [443];
  hm = {
    virtualisation.quadlet = {
      containers = {
        caddy = {
          autoStart = true;
          serviceConfig = {
            RestartSec = "10";
            Restart = "always";
          };
          containerConfig = {
            image = "docker.io/library/caddy:latest";
            publishPorts = ["80:80" "443:443" "443:443/udp"];
            volumes = [
              "${caddy-config}:/etc/caddy"
              "${caddy-site}:/srv"
              "${caddy-data}:/data"
              "${caddy-data-config}:/config"
            ];
            networks = ["searxng" "homepage"];
            # Doesn't have a normal user.
            user = funcs.mkUser "root" vars.mainGroup;
            # dropCapabilities = vars.rootCapabilities;
            uidMaps = funcs.mkUidMaps vars.n;
            gidMaps =
              funcs.mkGidMaps
              vars.n
              ([vars.mainGroup] ++ vars.groups);
            addGroups =
              funcs.mkAddGroups
              vars.groups;
          };
        };
      };
    };
  };
}
