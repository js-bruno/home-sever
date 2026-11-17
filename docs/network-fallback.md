# Watchdog do link cabeado do shatterdome (enp3s0)

O servidor tem **um único uplink**: `enp3s0`, com IP fixo
`192.168.15.50/24` e gateway `192.168.15.1`. Não há Wi-Fi nem segunda
placa de rede configurada.

O `net-fallback.service` não troca para outro caminho (não existe outro).
Ele mantém e restaura o link cabeado:

- garante `ip link set enp3s0 up`;
- recria o endereço `192.168.15.50/24` se ele sumir;
- recria a rota default `via 192.168.15.1 dev enp3s0 metric 100` se o
  kernel removê-la depois de uma queda/retorno do cabo;
- testa internet de verdade (`https://1.1.1.1/cdn-cgi/trace` e
  `https://www.gstatic.com/generate_204`) pela interface;
- registra no journal quando o link/ISP cai e quando volta.

Quando o cabo/roteador volta, a conectividade é restabelecida sem reboot.

## Limitação importante

Com um único uplink não é possível continuar online se o cabo, a porta do
switch, o roteador ou o ISP caírem. O watchdog **restabelece** a conexão
quando o link volta, mas não tem para onde alternar. Para redundância real
seria necessário um segundo uplink (outra placa/roteador/ISP ou 4G), o que
não está configurado.

## Verificar

```bash
systemctl status net-fallback --no-pager
journalctl -u net-fallback -f
ip -4 addr show dev enp3s0
ip route show default
```

Log esperado com tudo normal:

```
link=up internet=ok falhas=0 | default=default via 192.168.15.1 dev enp3s0 proto static metric 100
```

Sem internet:

```
link=up internet=falha falhas=3 | default=default via 192.168.15.1 dev enp3s0 proto static metric 100
sem internet pelo enp3s0; não há segundo uplink configurado. Confira cabo, porta do switch e roteador/ISP.
```

## Testar a recuperação

Pelo console (não derrube o SSH se estiver acessando por ele):

```bash
# simula queda de link; o watchdog deve recolocar o link up
sudo ip link set dev enp3s0 down
journalctl -u net-fallback -f
sleep 15
ip -4 addr show dev enp3s0
ip route show default

# simula perda de endereço/rota sem derrubar o link
sudo ip addr del 192.168.15.50/24 dev enp3s0
sudo ip route del default via 192.168.15.1 dev enp3s0 proto static metric 100
sleep 15
ip -4 addr show dev enp3s0
ip route show default
```

Em até ~10 s o endereço e a rota devem voltar. Se o cabo estiver
desconectado, o watchdog mantém o link up mas não inventa conectividade;
ao reconectar, a configuração é restaurada.

## Diagnóstico

```bash
# estado do link e da porta
ip -br link show enp3s0
cat /sys/class/net/enp3s0/carrier
ethtool enp3s0 2>/dev/null || true

# endereço/rota/DNS
ip -4 addr show dev enp3s0
ip route show default
cat /etc/resolv.conf

# logs
journalctl -u net-fallback -n 100 --no-pager
journalctl -u network-addresses-enp3s0 -n 50 --no-pager
```

Se o endereço ou a rota não voltarem, rode manualmente:

```bash
sudo systemctl restart network-addresses-enp3s0.service
sudo systemctl restart net-fallback.service
```

## Rollback

A mudança é só de rede; volte para a geração anterior:

```bash
sudo nixos-rebuild switch --rollback
```

Ou escolha a geração anterior no menu do systemd-boot. O console local
resolve se a rede ficar inacessível.
