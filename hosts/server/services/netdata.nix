{ config, lib, ... }:
{
  services.netdata.enable = true;

  # Só aceita conexão local — a LAN entra pelo proxy reverso
  # (reverse-proxy.nix → http://netdata.thisdev.space)
  services.netdata.config = {
    web = {
      "bind to" = "127.0.0.1";
    };
  };
}