# excalidraw.nix — Excalidraw self-hosted (officiell app, sem colaboração)
#
# O app oficial do Excalidraw não tem binary/módulo NixOS: o upstream publica
# um container (excalidraw/excalidraw) que serve o frontend estático. Aqui
# rodamos ele via oci-containers (podman) e expomos pela LAN no vhost
# meuexcalidraw.com, SEM abrir porta direta no firewall — o único caminho de
# entrada é o nginx (reverse-proxy.nix).
#
# Obs.: o self-host oficial não suporta colaboração em tempo real (drawings
# são salvos no navegador/export). Para colaboração seriam necessários o
# excalidraw-room (websocket) + backend próprio — fora do escopo.

{ config, lib, pkgs, ... }:
let
  port = 5000; # porta interna do container (nginx proxy)
in
{
  # Executor de containers do NixOS; roda sem root e sem docker daemon
  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers.excalidraw = {
    image = "docker.io/excalidraw/excalidraw:latest";
    # Não precisa de volumes — dados ficam no localStorage do browser
    ports = [ "127.0.0.1:${toString port}:80" ];
    extraOptions = [ "--pull=newer" ];
  };

  # Vhost LAN: nome resolvido pelo dnsmasq (dnsmasq.nix), proxy para o podman
  services.nginx.virtualHosts."meuexcalidraw.com" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        allow 192.168.15.0/24;
        allow 127.0.0.1;
        deny all;
      '';
    };
  };
}