{
  description = "Desktop And Server Configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";

    desktop_user = "bruno";
    desktop_config = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hosts/desktop/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${server_user} = {
              imports = [ ./home/common.nix ./home/desktop.nix ];
            };
          }
      ];

    };

    server_user = "gipsydanger";
    server_config = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hosts/server/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${desktop_user} = {
              imports = [ ./home/common.nix ./home/server.nix ];
            };
          }
      ];
    };
  in
  {
      nixosConfigurations = {
        desktop = desktop_config;
        server = server_config;
      };
  };
}
