{
  vars,
  funcs,
  config,
  lib,
  ...
}: let
  localVars = vars.containers.containers.swag;
  swagImage = "lscr.io/linuxserver/swag:5.2.2";
  swagConfigDir = "${vars.containers.dataDir}/swag/config";
  swagContainerPUID = "1000";
  swagHostPUID = toString ((lib.toInt swagContainerPUID) + vars.containers.uidGidCount * localVars.i + (builtins.elemAt config.users.users.${vars.username}.subUidRanges 0).startUid);
in {
  options.opts.containers.swag = {
    enable = lib.mkEnableOption "SWAG";
    autoStart = lib.mkEnableOption "SWAG auto-start";
  };

  config = lib.mkIf config.opts.containers.swag.enable {
    systemd.tmpfiles.rules = [
      "d ${vars.containers.dataDir}/swag 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${swagConfigDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
      "Z ${swagConfigDir}/* 770 ${swagHostPUID} ${localVars.mainGroup} - -"
      # Symlinks aren't created if the target directory has a different owner.
      "d ${swagConfigDir}/dns-conf 770 ${vars.username} ${localVars.mainGroup} - -"
      "L+ ${swagConfigDir}/dns-conf/porkbun.ini - - - - ${config.secrets.certbot-porkbun.path}"
    ];
    secrets.certbot-porkbun = {
      sopsFile = ./porkbun.ini;
      format = "ini";
      # Entire file.
      key = "";
      # Only the user and group can read and nothing else.
      mode = "0440";
      owner = vars.username;
      group = localVars.mainGroup;
    };
    networking.firewall.allowedTCPPorts = [80 443];
    hm = {
      virtualisation.quadlet = {
        containers = {
          swag = funcs.containers.mkConfig "root" localVars {
            autoStart = config.opts.containers.swag.autoStart;
            containerConfig = {
              image = swagImage;
              publishPorts = [
                "443:443"
                "80:80"
              ];
              environments = {
                PUID = swagContainerPUID;
                PGID = funcs.containers.getContainerGid localVars.mainGroup;
                TZ = "Europe/Lisbon";
                URL = "orangepebble.net";
                SUBDOMAINS = "wildcard";
                VALIDATION = "dns";
                DNSPLUGIN = "porkbun";
              };
              volumes = [
                "${swagConfigDir}:/config"
                "${config.secrets.certbot-porkbun.path}:${config.secrets.certbot-porkbun.path}"
              ];
              addCapabilities = ["NET_ADMIN"];
            };
          };
        };
      };
    };
  };
}
