{
  config,
  lib,
  funcs,
  vars,
  ...
}: {
  opts.funcs.containers = {
    mkGroups = groups:
      lib.listToAttrs (lib.genList (i: {
        name = lib.elemAt groups i;
        value = {
          gid = vars.containers.startGid + i;
          members = [vars.username];
        };
      }) (lib.length groups));

    # '+ 100000' so that these mapped gids don't conflict with the others.
    getContainerGid = group: toString (config.users.groups.${group}.gid + 100000);

    mkUidMaps = n: ["0:${toString (1 + vars.containers.uidGidCount * n)}:${toString vars.containers.uidGidCount}"];

    # Gives me space for 1000 custom groups. Very overkill
    # I tried using 'lib.length groups' for automatic expansion but it
    #  caused problems when adding groups.
    mkGidMaps = n: gs:
      [
        "0:${toString (1 + 1000 + vars.containers.uidGidCount * n)}:${toString vars.containers.uidGidCount}"
      ]
      ++ (map (g: "${funcs.containers.getContainerGid g}:${toString (config.users.groups.${g}.gid - vars.containers.startGid + 1)}:1") gs);

    mkAddGroups = map (g: "${funcs.containers.getContainerGid g}");
    mkUser = user: group: "${user}:${funcs.containers.getContainerGid group}";
  };
}
