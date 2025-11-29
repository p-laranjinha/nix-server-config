# nix-server-config

My NixOS configuration for my server/NAS/homelab.

## Some thoughts

As I used disko to do the initial partition and filesystem setup, I could've imported it in the NixOS configuration to handle filesystems instead of using the fileSystems option, but because I don't know how disko would've handled future disk additions, because I of the /home problems (ZFS and systemd both tried to mount it and caused problems, unless the mountpoint was legacy) which forced me to use the fileSystems option just for it (now that I think about it, maybe disko would've handled it even though it didn't mount it during initial install), and because it was simple enough, I just ended up leaving the disko file only for the initial installation and using the fileSystems option like normal.

Look at comments in my .nix files for additional thoughts.
The comments in the [disko-config.nix](./disko-config.nix) file have a lot of thoughts about ZFS.

## Initial install

I did a bunch of experiments to learn and figure out what I wanted with both disko and ZFS, but here is what I ended up doing for my initial install.

I booted into a NixOS live boot ISO.

I downloaded a disko setup to modify into the state in this repo.
```bash
nix --extra-experimental-features "nix-command flakes" flake init --template github:nix-community/disko-templates#zfs-impermanence
```

I ran disko to partition, format, and mount the disks.
```bash
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount disko-config.nix
```

My disko configuration made /home use the ZFS legacy mountpoint, as both ZFS and systemd were trying to both mount it and it caused problems.
With the legacy mountpoint /home isn't automatically mounted when running disko, but it should be mounted during inital install, so I mount it manually.
```bash
sudo mkdir /mnt/home
sudo mount -t zfs zdata/home /mnt/home
```

I generated some initial NixOS config files to later modify into whats in this repo.
I also used this command just to easily create the required path.
I included `--no-filesystems` because I intended to let disko handle filesystems, but I ended up not doing that.
```bash
sudo nixos-generate-config --no-filesystems --root /mnt
```

I ran the final command to install NixOS. Keep in mind that this command will ask you at the end to input the root user's password. Additionally, when I ran this the configuration didn't use flakes so it'll have to be different for a flake config.
```bash
sudo nixos-install
```

After rebooting, I logged into root and ran the following to setup my main user's password.
```bash
passwd pebble
```

### Some commands I used to experiment before the initial install

```bash
# Makes me not need to use sudo for the following commands.
sudo -i
# Installed ZFS utilities.
nix-shell -p zfs
# Get info about the ZFS pools.
zpool list
zpool status zdata
zpool get ashift
# Add a new disk/partition to a pool.
zpool attach zdata raidz2-0 sd*
# Create a 20Gb file with random contents.
head -c 20G /dev/urandom > <file>
```
