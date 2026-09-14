{
  description = "My Server Configuration in nix";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nix-minecraft.inputs.nixpkgs.follows = "nixpkgs";
    hermes-agent.url = "github:NousResearch/hermes-agent";
  };

  outputs = { self, nixpkgs, home-manager, nix-minecraft, hermes-agent, ... }@inputs:
  let
    system = "x86_64-linux";
    server_user = "gipsydanger";
    server_config = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
          ./hosts/server/configuration.nix
          hermes-agent.nixosModules.default
          nix-minecraft.nixosModules.minecraft-servers
          { nixpkgs.overlays = [ nix-minecraft.overlay ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${server_user} = {
              imports = [ ./home/home.nix ];
            };
          }
      ];
    };
  in
  {
      nixosConfigurations = {
        server = server_config;
      };
  };
}
