{
  description = "My Server Configuration in nix";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent.url = "github:NousResearch/hermes-agent";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nix-minecraft.inputs.nixpkgs.follows = "nixpkgs";
    # Stack Habbo Retro (Arcturus + Atom CMS + Nitro client) como módulo NixOS
    habbo-nixos.url = "github:js-bruno/habbo-retro-nix";
    habbo-nixos.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, hermes-agent, nix-minecraft, habbo-nixos, ... }@inputs:
  let
    system = "x86_64-linux";
    server_user = "gipsydanger";
    server_config = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
          ./hosts/server/configuration.nix
          habbo-nixos.nixosModules.habbo
          nix-minecraft.nixosModules.minecraft-servers
          { nixpkgs.overlays = [ nix-minecraft.overlay ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${server_user} = {
              imports = [
                ./home/home.nix
                hermes-agent.homeManagerModules.default
              ];
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
