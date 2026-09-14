{ pkgs, ... }:{
  services.mysql = {
    enable = true;
    package = pkgs.mariadb_1011;
  };
}
