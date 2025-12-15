# https://github.com/immich-app/immich
{
  vars,
  funcs,
  lib,
  config,
  ...
}: let
  localVars = vars.containers.containers;
  # Obtained versions from the release 'docker-compose.yml'.
  immichImage = "ghcr.io/immich-app/immich-server:v2.3.1";
  redisImage = "ghcr.io/valkey-io/valkey:8.1.5@sha256:e6519c81133f55170dcaf1c7711dea0770dc756a7aef0cb919204c8d6e325776";
  databaseImage = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23";
  machineLearningImage = "ghcr.io/immich-app/immich-machine-learning:v2.3.1";

  immichUploadDir = "${vars.containers.publicDir}/images";
  databaseDataDir = "${vars.containers.dataDir}/immich/database/data";
  machineLearningCacheDir = "${vars.containers.dataDir}/immich/machine-learning/cache";

  env = {
    TZ = "Europe/Lisbon";
    DB_USERNAME = "postgres";
    DB_PASSWORD = "postgres"; # TODO: change to use a sops encrypted password
    DB_DATABASE_NAME = "immich";
  };
in {
  options.opts.containers.immich = {
    enable = lib.mkEnableOption "Immich";
    autoStart = lib.mkEnableOption "Immich auto-start";
  };

  config = lib.mkIf config.opts.containers.immich.enable {
    systemd.tmpfiles.rules = [
      "d ${immichUploadDir} 2770 ${vars.username} public - -"

      "d ${vars.containers.dataDir}/immich 2770 ${vars.username} ${localVars.immich.mainGroup} - -"

      "d ${vars.containers.dataDir}/immich/database 2770 ${vars.username} ${localVars.immich-database.mainGroup} - -"
      "d ${databaseDataDir} 2770 ${vars.username} ${localVars.immich-database.mainGroup} - -"

      "d ${vars.containers.dataDir}/immich/machine-learning 2770 ${vars.username} ${localVars.immich-machine-learning.mainGroup} - -"
      "d ${machineLearningCacheDir} 2770 ${vars.username} ${localVars.immich-machine-learning.mainGroup} - -"

      "Z ${immichUploadDir} 2770 ${vars.username} public - -"
      "Z ${vars.containers.dataDir}/immich 2770 ${vars.username} ${localVars.immich.mainGroup} - -"
      "Z ${vars.containers.dataDir}/immich/database 2770 ${vars.username} ${localVars.immich-database.mainGroup} - -"
      "Z ${vars.containers.dataDir}/immich/machine-learning 2770 ${vars.username} ${localVars.immich-machine-learning.mainGroup} - -"
    ];
    hm = {
      virtualisation.quadlet = {
        # https://github.com/linux-universe/immich-podman-quadlets
        containers = {
          immich = {
            autoStart = config.opts.containers.immich.autoStart;
            serviceConfig = {
              RestartSec = "10";
              Restart = "always";
            };
            # This makes it so that the other containers can have autoStart as
            #  false, but even so this container will start before the ones
            #  it depends on and fail at least once per startup.
            unitConfig = {
              Requires = "immich-redis.container immich-database.container";
              Wants = "immich-machine-learning.container";
            };
            containerConfig = {
              image = immichImage;
              publishPorts = ["2283:2283"];
              environments = env;
              volumes = [
                "${immichUploadDir}:/data"
                "/etc/localtime:/etc/localtime:ro"
              ];
              networks = ["immich"];
              user = funcs.containers.mkUser "node" localVars.immich.mainGroup;
              uidMaps = funcs.containers.mkUidMaps localVars.immich.n;
              gidMaps =
                funcs.containers.mkGidMaps
                localVars.immich.n
                ([localVars.immich.mainGroup] ++ localVars.immich.groups);
              addGroups =
                funcs.containers.mkAddGroups
                localVars.immich.groups;
            };
          };
          immich-machine-learning = {
            autoStart = false;
            serviceConfig = {
              RestartSec = "10";
              Restart = "always";
            };
            containerConfig = {
              image = machineLearningImage;
              volumes = [
                "${machineLearningCacheDir}:/cache"
              ];
              networks = ["immich"];
              networkAliases = ["immich-machine-learning"];
              user = funcs.containers.mkUser "root" localVars.immich-machine-learning.mainGroup;
              dropCapabilities = vars.containers.rootCapabilities;
              uidMaps = funcs.containers.mkUidMaps localVars.immich-machine-learning.n;
              gidMaps =
                funcs.containers.mkGidMaps
                localVars.immich-machine-learning.n
                ([localVars.immich-machine-learning.mainGroup] ++ localVars.immich-machine-learning.groups);
              addGroups =
                funcs.containers.mkAddGroups
                localVars.immich-machine-learning.groups;
            };
          };
          immich-redis = {
            autoStart = false;
            serviceConfig = {
              RestartSec = "10";
              Restart = "always";
            };
            containerConfig = {
              image = redisImage;
              networks = ["immich"];
              networkAliases = ["redis"];
              user = funcs.containers.mkUser "valkey" localVars.immich-redis.mainGroup;
              uidMaps = funcs.containers.mkUidMaps localVars.immich-redis.n;
              gidMaps =
                funcs.containers.mkGidMaps
                localVars.immich-redis.n
                ([localVars.immich-redis.mainGroup] ++ localVars.immich-redis.groups);
              addGroups =
                funcs.containers.mkAddGroups
                localVars.immich-redis.groups;
            };
          };
          immich-database = {
            autoStart = false;
            serviceConfig = {
              RestartSec = "10";
              Restart = "always";
            };
            containerConfig = {
              image = databaseImage;
              environments = {
                POSTGRES_USER = env.DB_USERNAME;
                POSTGRES_PASSWORD = env.DB_PASSWORD;
                POSTGRES_DB = env.DB_DATABASE_NAME;
                POSTGRES_INITDB_ARGS = "--data-checksums";
                DB_STORAGE_TYPE = "HDD";
              };
              volumes = [
                "${databaseDataDir}:/var/lib/postresql/data"
              ];
              shmSize = "128mb";
              networks = ["immich"];
              networkAliases = ["database"];
              user = funcs.containers.mkUser "postgres" localVars.immich-database.mainGroup;
              uidMaps = funcs.containers.mkUidMaps localVars.immich-database.n;
              gidMaps =
                funcs.containers.mkGidMaps
                localVars.immich-database.n
                ([localVars.immich-database.mainGroup] ++ localVars.immich-database.groups);
              addGroups =
                funcs.containers.mkAddGroups
                localVars.immich-database.groups;
            };
          };
        };
        networks.immich = {};
      };
    };
  };
}
