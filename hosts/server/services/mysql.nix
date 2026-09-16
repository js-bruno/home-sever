{ pkgs, ... }: {
  services.mysql = {
    enable = true;
    package = pkgs.mariadb_1011;

    # Cria o banco `habbo` na primeira inicialização do serviço
    initialDatabases = [
      { name = "habbo"; }
    ];

    # Cria usuário com senha para o PHP-FPM (pool `habbo` roda como nginx,
    # então auth por unix_socket não serviria). Troque a senha se o host
    # for exposto na rede.
    initialScript = pkgs.writeText "habbo-mysql-init.sql" ''
      CREATE USER IF NOT EXISTS 'habbo'@'localhost' IDENTIFIED BY 'habbo123';
      CREATE USER IF NOT EXISTS 'habbo'@'127.0.0.1' IDENTIFIED BY 'habbo123';
      GRANT ALL PRIVILEGES ON habbo.* TO 'habbo'@'localhost';
      GRANT ALL PRIVILEGES ON habbo.* TO 'habbo'@'127.0.0.1';
      FLUSH PRIVILEGES;
    '';
  };
}