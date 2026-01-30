#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash
# shellcheck shell=bash

NIX_CONFIG_DIR=/home/pebble/nix-server-config

# cd to your config dir without affecting shell outside this script.
pushd $NIX_CONFIG_DIR &>/dev/null

# Check if submodules are up to date and warn the user.
gum log --time timeonly --level info "Checking submodules..."
check_submodule() {
	git diff HEAD --quiet
	if [ $? -eq 0 ]; then
		gum log --time timeonly --level info "Submodule '$name' has no uncommitted files."
	else
		gum log --time timeonly --level warn "Submodule '$name' has uncommitted files."
		gum confirm "Continue?"
		if [ $? -eq 1 ]; then
			exit 1
		fi
	fi

	git fetch --quiet

	# https://stackoverflow.com/a/3278427
	UPSTREAM=${1:-'@{u}'}
	LOCAL=$(git rev-parse @)
	REMOTE=$(git rev-parse "$UPSTREAM")
	BASE=$(git merge-base @ "$UPSTREAM")

	if [ $LOCAL = $REMOTE ]; then
		gum log --time timeonly --level info "Submodule '$name' is up to date."
	else
		if [ $LOCAL = $BASE ]; then
			gum log --time timeonly --level warn "Submodule '$name' is outdated."
		elif [ $REMOTE = $BASE ]; then
			gum log --time timeonly --level warn "Submodule '$name' has not pushed its changes."
		else
			gum log --time timeonly --level warn "Submodule '$name' has diverged from origin."
		fi
		gum confirm "Continue?"
		if [ $? -eq 1 ]; then
			exit 1
		fi
	fi
}
export -f check_submodule
git submodule --quiet foreach check_submodule
if [ $? -ne 0 ]; then
	exit 1
fi

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
treefmt
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

git diff HEAD --quiet
if [ $? -eq 0 ]; then
	gum log --time timeonly --level error "No changes have been found. Use 'nixs' instead."
	exit 1
fi

git diff HEAD | delta --paging always
gum log --time timeonly --level info "Finished showing diff."

gum log --time timeonly --level info "Committing changes..."
COMMIT_SUMMARY=$(gum input --width 50 --header "Input commit summary:" --placeholder "")
if [ $? -ne 0 ]; then
	gum log --time timeonly --level error "No commit message."
	exit 1
fi
COMMIT_DESCRIPTION=$(gum write --width 80 --header "Input commit description:" --placeholder "")
git commit -m "$COMMIT_SUMMARY" -m "$COMMIT_DESCRIPTION"
if [ $? -eq 0 ]; then
	gum log --time timeonly --level info "Committed changes."
else
	gum log --time timeonly --level error "Failed committing files."
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

gum log --time timeonly --level info "Pushing to origin..."
git push
if [ $? -eq 0 ]; then
	gum log --time timeonly --level info "Pushed to origin."
else
	gum log --time timeonly --level error "Failed to push to origin."
	exit 1
fi

echo "Run 'psr' to restart plasma shell."
