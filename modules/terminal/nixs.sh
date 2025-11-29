#! /usr/bin/env nix-shell 
#! nix-shell -i bash -p bash gum kdePackages.kdbusaddons kdePackages.kde-cli-tools

NIX_CONFIG_DIR=/home/pebble/nix-server-config

# cd to your config dir without affecting shell outside this script.
pushd $NIX_CONFIG_DIR &>/dev/null

# Update files gotten using fetchgit which have a comment on the rev or url attribute.
gum log --time timeonly --level info "Updating fetchgit commit references..."
fd .nix --exec update-nix-fetchgit --only-commented
if [ $? -eq 0 ]; then
	gum log --time timeonly --level info "Updated fetchgit commit references."
else
	gum log --time timeonly --level warn "Failed to update fetchgit commit references."
fi

# Autoformat the nix files.
gum log --time timeonly --level info "Formatting files..."
alejandra -q .
if [ $? -eq 0 ]; then
	gum log --time timeonly --level info "Finished formatting files."
else
	gum log --time timeonly --level error "Failed formatting files."
	exit 1
fi

gum log --time timeonly --level info "Staging files..."
git add .
if [ $? -eq 0 ]; then
	gum log --time timeonly --level info "Staged files."
else
	gum log --time timeonly --level error "Failed staging files."
	exit 1
fi

gum log --time timeonly --level info "Rebuilding..."
sudo nixos-rebuild switch --flake .
if [ $? -eq 0 ]; then
	gum log --time timeonly --level info "Finished rebuilding."
else
	gum log --time timeonly --level error "Failed rebuild."
	exit 1
fi

echo "Run 'psr' to restart plasma shell."
