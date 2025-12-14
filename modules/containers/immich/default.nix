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
  serverImage = "ghcr.io/immich-app/immich-server:v2.3.1";
  redisImage = "docker.io/valkey/valkey:8@sha256:81db6d39e1bba3b3ff32bd3a1b19a6d69690f94a3954ec131277b9a26b95b3aa";
  databaseImage = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23";
  machineLearningImage = "ghcr.io/immich-app/immich-machine-learning:v2.3.1";

  serverUploadDir = "${vars.containers.publicDir}/images";
  databaseDataDir = "${vars.containers.dataDir}/immich/database/data";
  machineLearningCacheDir = "${vars.containers.dataDir}/immich/machine-learning/cache";

  env = {
    TZ = "Europe/Lisbon";
    DB_USERNAME = "postgres";
    DB_PASSWORD = "postgres"; # TODO: change to use a sops encrypted password
    DB_DATABASE_NAME = "immich";
  };
in {
  options.opts.containers.immich.enable = lib.mkOption {
    default = config.opts.containers.enable;
    type = lib.types.bool;
  };

  config = lib.mkIf config.opts.containers.immich.enable {
    systemd.tmpfiles.rules = [
      "d ${serverUploadDir} 2770 ${vars.username} public - -"

      "d ${vars.containers.dataDir}/immich 2770 ${vars.username} ${localVars.immich-server.mainGroup} - -"

      "d ${vars.containers.dataDir}/immich/database 2770 ${vars.username} ${localVars.immich-database.mainGroup} - -"
      "d ${databaseDataDir} 2770 ${vars.username} ${localVars.immich-database.mainGroup} - -"

      "d ${vars.containers.dataDir}/immich/machine-learning 2770 ${vars.username} ${localVars.immich-machine-learning.mainGroup} - -"
      "d ${machineLearningCacheDir} 2770 ${vars.username} ${localVars.immich-machine-learning.mainGroup} - -"
    ];
    hm = {
      virtualisation.quadlet = {
        # https://github.com/linux-universe/immich-podman-quadlets
        containers = {
          immich-server = {
            autoStart = true;
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
              image = serverImage;
              publishPorts = ["2283:2283"];
              environments = env;
              volumes = [
                "${serverUploadDir}:/data"
                "/etc/localtime:/etc/localtime:ro"
              ];
              networks = ["immich"];
              user = funcs.containers.mkUser "node" localVars.immich-server.mainGroup;
              uidMaps = funcs.containers.mkUidMaps localVars.immich-server.n;
              gidMaps =
                funcs.containers.mkGidMaps
                localVars.immich-server.n
                ([localVars.immich-server.mainGroup] ++ localVars.immich-server.groups);
              addGroups =
                funcs.containers.mkAddGroups
                localVars.immich-server.groups;
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
