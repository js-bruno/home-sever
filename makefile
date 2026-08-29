collect-garbage:
	sudo nix-collect-garbage --delete-older-than 7d


build:
	sudo nixos-rebuild switch --flake .#server

