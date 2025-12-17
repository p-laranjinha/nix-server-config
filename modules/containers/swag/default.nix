{
  vars,
  funcs,
  config,
  lib,
  ...
}: let
  localVars = vars.containers.containers.swag;
in {
  options.opts.containers.swag = {
    enable = lib.mkEnableOption "SWAG";
    autoStart = lib.mkEnableOption "SWAG auto-start";
  };

  config = lib.mkIf config.opts.containers.swag.enable {
    systemd.tmpfiles.rules = [];
    # Allow non-root users to bind to privileged ports like 80.
    boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
    networking.firewall.allowedTCPPorts = [80 443];
    hm = {
      virtualisation.quadlet = {
        containers = {
          swag = funcs.containers.mkConfig "nginx" localVars {
            autoStart = config.opts.containers.swag.autoStart;
            containerConfig = {
              image = "lscr.io/linuxserver/swag";
              publishPorts = [
                "443:443"
                "80:80"
              ];
              environments = {
                TZ = "Europe/Lisbon";
              };
              volumes = [];
              addCapabilities = ["NET_ADMIN"];
            };
          };
        };
      };
    };
  };
}
