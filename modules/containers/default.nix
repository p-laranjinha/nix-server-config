{
  inputs,
  this,
  lib,
  config,
  ...
}: let
  mkVars = lib.mapAttrs (_: v:
    if (lib.typeOf v) == "set"
    then mkVars v
    else lib.mkOption {default = v;});
  mkGroups = groups:
    lib.listToAttrs (lib.genList (i: {
      name = lib.elemAt groups i;
      value = {
        gid = startGid + i;
        members = [this.username];
      };
    }) (lib.length groups));
  mkSubGidRanges = groups:
    lib.genList (i: {
      count = 1;
      startGid = startGid + i;
    }) (lib.length groups);

  # '+ 100000' so that these mapped gids don't conflict with the others.
  getContainerGid = group: toString (config.users.groups.${group}.gid + 100000);

  # How many uids and gids the containers will have allocated to them.
  # Will map from 0-1999. More than enough for most containers.
  uidGidCount = 2000;
  # The groups defined in 'groups' start with this gid.
  startGid = 1001;
  groups = [
    "searxng"
    "searxng-valkey"
    "homepage"
    # "public" # For everything that may be exposed to the internet.
  ];
in {
  options = mkVars {
    vars = {
      # Defining these here so there is less of a risk of overlapping.
      # 'n' is used to define what subuid and subgids each container uses.
      # 'mainGroup' is used to define the container's primary group, and what
      #   owner group the volumes should have. Volumes may have a different group
      #   owner if they're also going to be used by other containers, like 'public'.
      # 'groups' are the additional groups the container's user belongs to, so
      #   the container is able to access shared volumes.
      containers = {
        searxng = {
          n = 0;
          mainGroup = "searxng";
          groups = [];
        };
        searxng-valkey = {
          n = 1;
          mainGroup = "searxng-valkey";
          groups = [];
        };
        homepage = {
          n = 2;
          mainGroup = "homepage";
          groups = [];
        };
      };
      containerDataDir = "${this.homeDirectory}/container-data";
    };
    funcs = {
      containers = {
        mkUidMaps = n: ["0:${toString (1 + uidGidCount * n)}:${toString uidGidCount}"];
        mkGidMaps = n: gs:
          [
            "0:${toString (1 + (lib.length groups) + uidGidCount * n)}:${toString uidGidCount}"
          ]
          ++ (map (g: "${getContainerGid g}:${toString (config.users.groups.${g}.gid - startGid + 1)}:1") gs);
        mkAddGroups = map (g: "${getContainerGid g}");
        mkUser = user: group: "${user}:${getContainerGid group}";
      };
    };
  };

  imports =
    [inputs.quadlet-nix.nixosModules.quadlet]
    ++ lib.attrValues (lib.modulesIn ./.);

  config = {
    systemd.tmpfiles.rules = [
      "d ${config.vars.containerDataDir} 6770 ${this.username} users - -"
    ];

    # Enable podman & podman systemd generator.
    virtualisation.quadlet.enable = true;
    users.users.${this.username} = {
      # Required for auto start before user login.
      linger = true;
      # Required for rootless container with multiple users.
      autoSubUidGidRange = true;
      subGidRanges = mkSubGidRanges groups;
    };
    users.groups = mkGroups groups;
    hm = {
      imports = [inputs.quadlet-nix.homeManagerModules.quadlet];
      virtualisation.quadlet = {
        autoEscape = true; # Will be default in the future.
      };
    };
  };
}
# Groups aren't deleted automatically because Nix doesn't know what files are
#  owned by the groups.
# So if you wan't to remove or change group order, you'll have to manually
#  remove the group using 'sudo groupdel <group>' and change the owner group of
#  the files/folders that need it.
# An easy way to change owner groups to every file/folder that needs it is by
#  running 'sudo find / -gid <OLD_GID> -exec chgrp <NEW_GID> {} +' before
#  running 'nixos-rebuild switch'.
#
# Container options:
#  https://seiarotg.github.io/quadlet-nix/home-manager-options.html
#
# Volumes don't support symlinks, so when I want to volume folders in this repo
#  it has to be directly.
#
# The following references gids but the same applies to uids:
# gidmaps don't directly map my host's groups to the container's, they map a
#  user's subgids. For example, if the subgids are from 100000-..., the
#  '0:1:2000' maps the host's 100000-102000 to the containers 0-2000.
#  The exception is '_:0:_' as that maps the host's current user's primary group.
# If you want to share a group between the container and the host (without
#  relying on the 'run.oci.keep_original_groups' annotation or on the
#  'keep-groups' groupAdd option, as that adds all of the host user's groups
#  to the containers), you'll have to create a group on the host and add it to
#  the user and user's subgids. For example, if you add the group 1001, the
#  gidmap '9999:1:1' would map the host's 1001 to the container's 9999, and the
#  default subgids would start to map from '_:2:_'.
#  I think the added subgid comes before the default ones because it is a
#  smaller gid, but I haven't tested it.
# Now, gidmaps are incompatible with the 'userns' option, so if you decide you
#  want to use it, you can't forget to map enough gids for all the groups the
#  container needs. Examples I've seen online map 1000 gids (ex: '0:1:1000'),
#  but 100 is probably already more than enough for most cases.
# Use 'cat /etc/group' to see all groups and 'cat /etc/passwd' to see all users.
# Another thing I haven't tested is if there is any problem with multiple
#  containers being mapped the same gids. I think it will run with no problems
#  but the containers will share the same host gids, which I'd imagine is not
#  the best for security.
#  Either way, there are enough gids to give each container a unique set, so
#  might as well just in case.
#
# These links are good sources of a simpler way to setup podman containers:
#  https://www.redhat.com/en/blog/rootless-podman-user-namespace-modes
#  https://www.redhat.com/en/blog/supplemental-groups-podman-containers
#
# https://www.redhat.com/en/blog/user-flag-rootless-containers
# I'm also using 'user="<user>"' to make the container not use the root user,
#  as even in rootless mode it still has more permissions. I find a valid user
#  by running 'podman exec -it <container> cat /etc/passwd' to list all users
#  (the best one to use is probably the last one).
# For containers that need to be root to run some utils, I'll remove the user
#  option but drop root's capabilities instead. Use the following to get the
#  capabilities of the current user: 'podman top <container> capeff'
# Changing the user or removing root capabilities makes the 'U' volume option
#  stop working, which then requires sharing host groups with write permissions.
#
# I'm using 'systemd.tmpfiles.rules' to automatically create directories and
#  set their permissions. Using 2___ permissions, makes it so the files created
#  in that directory inherit the group, so I can hopefully at least read the
#  files outside the container.

