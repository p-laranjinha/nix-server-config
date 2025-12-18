{
  vars,
  funcs,
  config,
  lib,
  ...
}: let
  localVars = vars.containers.containers.swag;
  swagImage = "lscr.io/linuxserver/swag:5.2.2";
  configDir = funcs.relativeToAbsoluteConfigPath ./config;
  defaultConfigDir = "${vars.containers.dataDir}/swag/config";
  nginxConfFile.source = "${configDir}/default.conf";
  nginxConfFile.destination = "${defaultConfigDir}/nginx/site-confs/default.conf";
  autheliaConfFile.source = "${configDir}/authelia.subdomain.conf";
  autheliaConfFile.destination = "${defaultConfigDir}/nginx/proxy-confs/authelia.subdomain.conf";
  homepageConfFile.source = "${configDir}/homepage.subdomain.conf";
  homepageConfFile.destination = "${defaultConfigDir}/nginx/proxy-confs/homepage.subdomain.conf";
  searxngConfFile.source = "${configDir}/searxng.subdomain.conf";
  searxngConfFile.destination = "${defaultConfigDir}/nginx/proxy-confs/searxng.subdomain.conf";
  immichConfFile.source = "${configDir}/immich.subdomain.conf";
  immichConfFile.destination = "${defaultConfigDir}/nginx/proxy-confs/immich.subdomain.conf";
  copypartyConfFile.source = "${configDir}/copyparty.subdomain.conf";
  copypartyConfFile.destination = "${defaultConfigDir}/nginx/proxy-confs/copyparty.subdomain.conf";
  containerPUID = "1000";
  hostPUID = toString ((lib.toInt containerPUID) + vars.containers.uidGidCount * localVars.i + (builtins.elemAt config.users.users.${vars.username}.subUidRanges 0).startUid);
in {
  options.opts.containers.swag = {
    enable = lib.mkEnableOption "SWAG";
    autoStart = lib.mkEnableOption "SWAG auto-start";
  };

  config = lib.mkIf config.opts.containers.swag.enable {
    systemd.tmpfiles.rules = [
      "d ${vars.containers.dataDir}/swag 2770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${defaultConfigDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
      "Z ${defaultConfigDir}/* 770 ${hostPUID} ${localVars.mainGroup} - -"
      # Symlinks aren't created if the destination directories have a different owner.
      "d ${defaultConfigDir}/dns-conf 770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${defaultConfigDir}/nginx 770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${defaultConfigDir}/nginx/site-confs 770 ${vars.username} ${localVars.mainGroup} - -"
      "d ${defaultConfigDir}/nginx/proxy-confs 770 ${vars.username} ${localVars.mainGroup} - -"

      "L+ ${defaultConfigDir}/dns-conf/porkbun.ini - - - - ${config.secrets.certbot-porkbun.path}"
      "d ${configDir} 2770 ${vars.username} ${localVars.mainGroup} - -"
      "Z ${configDir}/* 770 ${vars.username} ${localVars.mainGroup} - -"
      "L+ ${nginxConfFile.destination} - - - - ${nginxConfFile.source}"
      "L+ ${autheliaConfFile.destination} - - - - ${autheliaConfFile.source}"
      "L+ ${homepageConfFile.destination} - - - - ${homepageConfFile.source}"
      "L+ ${searxngConfFile.destination} - - - - ${searxngConfFile.source}"
      "L+ ${immichConfFile.destination} - - - - ${immichConfFile.source}"
      "L+ ${copypartyConfFile.destination} - - - - ${copypartyConfFile.source}"
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
        networks = {
          swag-searxng = {};
          swag-homepage = {};
          swag-immich = {};
          swag-copyparty = {};
        };
        containers = {
          searxng.containerConfig.networks = ["swag-searxng"];
          homepage.containerConfig.networks = ["swag-homepage"];
          immich.containerConfig.networks = ["swag-immich"];
          copyparty.containerConfig.networks = ["swag-copyparty"];
          swag = funcs.containers.mkConfig "root" localVars {
            autoStart = config.opts.containers.swag.autoStart;
            serviceConfig = {
              RestartSec = "10";
              Restart = "always";
            };
            containerConfig = {
              image = swagImage;
              publishPorts = [
                "443:443"
                "80:80"
              ];
              environments = {
                PUID = containerPUID;
                PGID = funcs.containers.getContainerGid localVars.mainGroup;
                TZ = "Europe/Lisbon";
                URL = "orangepebble.net";
                SUBDOMAINS = "wildcard";
                VALIDATION = "dns";
                DNSPLUGIN = "porkbun";
              };
              volumes = [
                "${defaultConfigDir}:/config"
                "${config.secrets.certbot-porkbun.path}:${config.secrets.certbot-porkbun.path}"
                "${nginxConfFile.source}:${nginxConfFile.source}"
                "${autheliaConfFile.source}:${autheliaConfFile.source}"
                "${homepageConfFile.source}:${homepageConfFile.source}"
                "${searxngConfFile.source}:${searxngConfFile.source}"
                "${immichConfFile.source}:${immichConfFile.source}"
                "${copypartyConfFile.source}:${copypartyConfFile.source}"
              ];
              networks = [
                "swag-searxng"
                "swag-homepage"
                "swag-immich"
                "swag-copyparty"
                # WARN: Everytime you change this, you need to remove
                #  '${defaultConfigDir}/nginx/resolver.conf' or else the
                #  new networks aren't used.
              ];
              addCapabilities = ["NET_ADMIN"];
            };
          };
        };
      };
    };
  };
}
