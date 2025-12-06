{
  vars,
  funcs,
  ...
}: let
  caddy-config = funcs.relativeToAbsoluteConfigPath ./config;
  # Directory to serve static files from.
  caddy-site = funcs.relativeToAbsoluteConfigPath ./site;
  caddy-data = "${vars.containers.dataDir}/caddy/data";
  caddy-data-config = "${vars.containers.dataDir}/caddy/config";
in {
  systemd.tmpfiles.rules = [
    "d ${caddy-config} 2770 ${vars.username} ${vars.containers.containers.caddy.mainGroup} - -"
    "d ${caddy-site} 2770 ${vars.username} ${vars.containers.containers.caddy.mainGroup} - -"
    "d ${vars.containers.dataDir}/caddy 2770 ${vars.username} ${vars.containers.containers.caddy.mainGroup} - -"
    "d ${caddy-data} 2770 ${vars.username} ${vars.containers.containers.caddy.mainGroup} - -"
    "d ${caddy-data-config} 2770 ${vars.username} ${vars.containers.containers.caddy.mainGroup} - -"
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
            user = funcs.containers.mkUser "root" vars.containers.containers.caddy.mainGroup;
            # dropCapabilities = vars.rootCapabilities;
            uidMaps = funcs.containers.mkUidMaps vars.containers.containers.caddy.n;
            gidMaps =
              funcs.containers.mkGidMaps
              vars.containers.containers.caddy.n
              ([vars.containers.containers.caddy.mainGroup] ++ vars.containers.containers.caddy.groups);
            addGroups =
              funcs.containers.mkAddGroups
              vars.containers.containers.caddy.groups;
          };
        };
      };
    };
  };
}
