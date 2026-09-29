# Glance (NixOS)

Referência completa do módulo NixOS [`services.glance`](https://github.com/glanceapp/glance),
convertida da [documentação oficial de configuração](https://github.com/glanceapp/glance/blob/main/docs/configuration.md)
para a sintaxe Nix.

Tudo o que está documentado aqui vive dentro de `services.glance.settings`, que é
serializado 1:1 para YAML pelo módulo. Ou seja, os exemplos abaixo são para colar
diretamente no seu `glance.nix`:

```nix
{ config, pkgs, ... }:
{
  services.glance = {
    enable = true;

    settings = {
      server = { port = 8082; };

      # ... tudo desta documentação vai aqui ...
    };
  };
}
```

> **Nota:** o módulo aceita um `settings` de forma livre (freeform YAML), então
> qualquer chave do Glance vira um atributo Nix equivalente.

## Página pré-configurada

Se você não quer ler todas as opções e só quer algo funcionando rapidamente, comece com
o exemplo acima e vá ajustando conforme o gosto. O resultado é uma página parecida com:

![preview da página pré-configurada](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/preconfigured-page-preview.png)

Configure os widgets, adicione mais, crie páginas extras e torne o dashboard seu.

## Índice

- [Página pré-configurada](#pagina-pre-configurada)
- [Configuração](#configuracao)
  - [Recarregamento automático](#recarregamento-automatico)
  - [Variáveis de ambiente](#variaveis-de-ambiente)
    - [Outras formas de fornecer tokens/senhas/segredos](#outras-formas-de-fornecer-tokenssenhassegredos)
  - [Incluindo outros arquivos de config](#incluindo-outros-arquivos-de-config)
  - [Ícones](#icones)
  - [Schema da config](#schema-da-config)
- [Autenticação](#autenticacao)
- [Server](#server)
- [Document](#document)
- [Branding](#branding)
- [Theme](#theme)
  - [Temas disponíveis](#temas-disponiveis)
- [Pages & Columns](#pages--columns)
- [Widgets](#widgets)
  - [Propriedades compartilhadas](#propriedades-compartilhadas)
  - [RSS](#rss)
  - [Videos](#videos)
  - [Hacker News](#hacker-news)
  - [Lobsters](#lobsters)
  - [Reddit](#reddit)
  - [Search](#search)
  - [Group](#group)
  - [Split Column](#split-column)
  - [Custom API](#custom-api)
  - [Extension](#extension)
  - [Weather](#weather)
  - [Todo](#todo)
  - [Monitor](#monitor)
  - [Releases](#releases)
  - [Docker Containers](#docker-containers)
  - [DNS Stats](#dns-stats)
  - [Server Stats](#server-stats)
  - [Repository](#repository)
  - [Bookmarks](#bookmarks)
  - [Calendar](#calendar)
  - [Calendar (legacy)](#calendar-legacy)
  - [ChangeDetection.io](#changedetectionio)
  - [Clock](#clock)
  - [Markets](#markets)
  - [Twitch Channels](#twitch-channels)
  - [Twitch Top Games](#twitch-top-games)
  - [iframe](#iframe)
  - [HTML](#html)

## Configuração

### Recarregamento automático

O recarregamento automático é suportado: mudanças no arquivo de config gerado
(`/run/glance/glance.yaml`) passam a valer no save, sem reiniciar o serviço. Mudanças
em variáveis de ambiente **não** disparam recarregamento e exigem reinício manual.

> **Nota:**
>
> Ao iniciar com config inválida, o Glance sai com erro. Se você iniciou com config
> válida e depois introduziu um erro, o erro aparece no log e o Glance continua rodando
> com a config antiga até você corrigir.

> **Cuidado:**
>
> Recarregar a config limpa o cache, forçando novas requisições às APIs. Isso pode
> causar rate limiting se feito com muita frequência.

### Variáveis de ambiente

É possível inserir variáveis de ambiente em qualquer lugar da config via a sintaxe
`${ENV_VAR}` (do Glance). **Em Nix, o `${...}` é uma interpolação da própria linguagem**,
então você precisa escapá-lo:

- dentro de strings `''...''`: use `''${ENV_VAR}`
- dentro de strings `"..."`: use `\''${ENV_VAR}`

O resultado no YAML gerado será o literal `${ENV_VAR}`, que o Glance interpreta como
variável de ambiente.

Exemplo:

```nix
server = {
  host = "''${HOST}";
  port = "''${PORT}";
};
```

Também funciona no meio de uma string:

```nix
{
  type = "rss";
  title = "''${RSS_TITLE}";
  feeds = [
    { url = "http://domain.com/rss/''${RSS_CATEGORY}.xml"; }
  ];
};
```

E com qualquer tipo de valor, não só strings:

```nix
{
  type = "rss";
  limit = "''${RSS_LIMIT}";
}
```

Para usar a sintaxe `${NAME}` sem que seja interpretada, escape com uma barra invertida.
Em Nix, para gerar `\${NAME}` no YAML, escreva `\''${NAME}`:

```nix
something = "\''${NOT_AN_ENV_VAR}";
```

#### Fornecendo variáveis de ambiente no NixOS

O módulo lê variáveis de ambiente via `services.glance.environmentFile`. Exemplo:

```nix
services.glance.environmentFile = "/var/lib/secrets/glance";

# conteúdo do arquivo:
#   TIMEZONE=Europe/Paris
```

E na config:

```nix
settings.pages = [
  {
    name = "Home";
    columns = [
      {
        size = "full";
        widgets = [
          {
            type = "clock";
            timezone = "''${TIMEZONE}";
            label = "Local Time";
          }
        ];
      }
    ];
  }
];
```

#### Outras formas de fornecer tokens/senhas/segredos

O módulo NixOS tem uma forma nativa de segredos. Qualquer valor de config pode ser
substituído pelo conteúdo de um arquivo usando a forma `_secret`:

```nix
{
  type = "weather";
  location = {
    _secret = "/var/lib/secrets/glance/location";
  };
}
```

O valor do atributo `_secret` é o caminho do arquivo cujo conteúdo substituirá o valor.
Isso evita expor segredos no `/nix/store` (que é world-readable).

Você também pode carregar o conteúdo de um arquivo cujo caminho vem de uma variável de
ambiente usando a sintaxe `${readFileFromEnv:VAR}`:

```nix
token = "''${readFileFromEnv:TOKEN_FILE}";
```

> **Nota:** o conteúdo do arquivo tem espaços em branco (início/fim) removidos antes de ser usado.

### Incluindo outros arquivos de config

O Glance suporta incluir arquivos via a diretiva `$include`, que é uma funcionalidade do
**YAML** (não do Nix). Em Nix, a forma idiomática de reutilizar configuração é com
bindings `let ... in` (veja [Group](#group) e [Split Column](#split-column)), então em
geral você não precisa do `$include`.

Se ainda assim precisar reproduzir o `$include`, você pode usar a chave `"$include"` como
atributo:

```nix
pages = [
  { "$include" = "home.yml"; }
  { "$include" = "videos.yml"; }
];
```

> **Nota:** em Nix, prefira compartilhar config com `let` bindings — é mais seguro,
> tipado e evita os problemas de número de linha/parse do `$include` no YAML.

### Ícones

Para widgets que aceitam ícone (`monitor`, `bookmarks`, `docker-containers`, etc.), use
a propriedade `icon` com uma URL ou nomes de bibliotecas com prefixo:

```nix
icon = "si:immich";   # si = Simple icons https://simpleicons.org/
icon = "sh:immich";   # sh = selfh.st icons https://selfh.st/icons/
icon = "di:immich";   # di = Dashboard icons https://github.com/homarr-labs/dashboard-icons
icon = "mdi:camera";  # mdi = Material Design icons https://pictogrammers.com/library/mdi/
```

Os prefixos `sh:` e `di:` pedem SVG por padrão. Se só houver PNG, adicione a extensão:

```nix
icon = "sh:unmanic.png";
```

Para inverter automaticamente a cor (ícones pretos que ficam brancos no tema escuro),
use o prefixo `auto-invert`:

```nix
icon = "auto-invert https://example.com/path/to/icon.png";
icon = "auto-invert sh:glance-dark";
```

Se não houver `.svg` para um ícone `selfh.st`/`Dashboard`, informe a extensão desejada:

```nix
icon = "sh:glance.png";
icon = "sh:glance.webp";
```

### Schema da config

Para descrições, validação e autocomplete da config no seu editor, existe um
[schema JSON](https://github.com/not-first/glance-schema) criado por @not-first.

## Autenticação

Autenticação por usuário/senha via propriedade `auth` no topo da config:

```nix
auth = {
  secret-key = "valor gerado com 'glance secret:make'";
  users = {
    admin.password = "123456";
    svilen.password = "123456";
  };
};
```

Para gerar a chave secreta, rode `glance secret:make` (ou `nix run nixpkgs#glance -- secret:make`).

### Usando senhas com hash

Em vez de guardar senha em texto puro, use o hash:

```sh
glance password:hash mysecretpassword
```

E na config, use `password-hash` em vez de `password`:

```nix
auth = {
  secret-key = "...";
  users = {
    admin.password-hash = "$2a$10$o6SXqiccI3DDP2dN4ADumuOeIHET6Q4bUMYZD6rT2Aqt6XQ3DyO.6";
  };
};
```

### Prevenindo força bruta

O Glance bloqueia IPs que falham 5 autenticações seguidas em 5 minutos. Atrás de um
reverse proxy, é preciso informar o IP real via `server.proxied = true`:

```nix
server = {
  proxied = true;
};
```

Quando `true`, o Glance usa o header `X-Forwarded-For` para descobrir o IP original.

## Server

Configuração via propriedade `server` no topo:

```nix
server = {
  host = "127.0.0.1";
  port = 8082;
  proxied = false;
  base-url = "/glance";
  assets-path = "/var/lib/glance/assets";
};
```

### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| host | string | não |  |
| port | número | não | 8080 |
| proxied | boolean | não | false |
| base-url | string | não | |
| assets-path | string | não |  |

#### `host`

Endereço no qual o servidor escuta. `localhost` restringe à própria máquina; por padrão
escuta em todas as interfaces.

#### `port`

Número entre 1 e 65.535 (desde que livre).

#### `proxied`

Defina `true` se houver reverse proxy na frente do Glance.

#### `base-url`

URL base sob a qual o Glance é hospedado (ex.: `/glance`), útil em reverse proxy com
subdiretório. A barra inicial é obrigatória.

#### `assets-path`

Caminho de um diretório servido em `/assets/`. Útil para auto-hospedar ícones do Monitor.

```nix
server.assets-path = "/var/lib/glance/assets";
# depois aponte: icon = "/assets/gitea-icon.png";
```

## Document

Para inserir HTML customizado no `<head>` de todas as páginas:

```nix
document = {
  head = ''
    <script src="/assets/custom.js"></script>
  '';
};
```

## Branding

Ajuste as partes visuais da marca via propriedade `branding`:

```nix
branding = {
  hide-footer = false;
  custom-footer = ''
    <p>Powered by <a href="https://github.com/glanceapp/glance">Glance</a></p>
  '';
  logo-text = "G";
  logo-url = "/assets/logo.png";
  favicon-url = "/assets/logo.png";
  app-name = "My Dashboard";
  app-icon-url = "/assets/app-icon.png";
  app-background-color = "#151519";
};
```

### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| hide-footer | boolean | não | false |
| custom-footer | string | não |  |
| logo-text | string | não | G |
| logo-url | string | não | |
| favicon-url | string | não | |
| app-name | string | não | Glance |
| app-icon-url | string | não | ícone padrão |
| app-background-color | string | não | cor padrão |

- `hide-footer` — esconde o rodapé.
- `custom-footer` — HTML customizado para o rodapé.
- `logo-text` — texto no lugar do "G" da navegação.
- `logo-url` — imagem no lugar do "G". Se `logo-url` e `logo-text` estiverem setados, só o `logo-url` vale.
- `favicon-url` — imagem customizada para o favicon.
- `app-name` — nome do web app (aba do navegador e PWA).
- `app-icon-url` — ícone do PWA/aba (PNG 512x512).
- `app-background-color` — cor de fundo do PWA (CSS válido).

## Theme

Cores em formato [HSL](https://giggster.com/guide/basics/hue-saturation-lightness/)
(hue, saturação, luminosidade), separadas por espaço (o `%` não é obrigatório). **Em Nix,
o valor HSL é uma string**:

```nix
theme = {
  background-color = "100 20 10";
  primary-color = "40 90 40";
  contrast-multiplier = 1.1;
  light = false;
  disable-picker = false;
  presets = {
    gruvbox-dark = {
      background-color = "0 0 16";
      primary-color = "43 59 81";
      positive-color = "61 66 44";
      negative-color = "6 96 59";
    };
    zebra = {
      light = true;
      background-color = "0 0 95";
      primary-color = "0 0 10";
      negative-color = "0 90 50";
    };
  };
};
```

### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| light | boolean | não | false |
| background-color | HSL | não | 240 8 9 |
| primary-color | HSL | não | 43 50 70 |
| positive-color | HSL | não | igual a `primary-color` |
| negative-color | HSL | não | 0 70 70 |
| contrast-multiplier | número | não | 1 |
| text-saturation-multiplier | número | não | 1 |
| custom-css-file | string | não | |
| disable-picker | boolean | não | false |
| presets | objeto | não | |

#### `light`

Se o esquema é claro ou escuro (inverte as cores de texto).

#### `background-color` / `primary-color` / `positive-color` / `negative-color`

Cor da página/widgets; cor de links; cor "positiva"; cor "negativa".

#### `contrast-multiplier`

Aumenta/diminui o contraste do texto. `1.3` = texto 30% mais claro/escuro.

![diferença entre contraste 1 e 1.3](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/contrast-multiplier-example.png)

#### `text-saturation-multiplier`

Aumenta/diminui a saturação do texto (`0.5` = 50% menos, `1.5` = 50% mais).

#### `custom-css-file`

Caminho de um CSS customizado (externo ou do assets path):

```nix
theme.custom-css-file = "/assets/my-style.css";
```

> **Dica:** cada widget tem a classe `widget-type-{name}`. Você também pode usar
> `css-class` em qualquer widget para classes customizadas.

#### `disable-picker`

Esconde o seletor de tema e desabilita a troca entre temas.

#### `presets`

Temas adicionais selecionáveis no seletor. Aceitam as mesmas propriedades do tema
padrão (exceto `custom-css-file`). Para sobrescrever os temas padrão, use as chaves
`default-dark` e `default-light`.

### Temas disponíveis

Se você não quer montar o próprio tema, há [vários temas prontos](https://github.com/glanceapp/glance/blob/main/docs/themes.md)
para copiar os valores.

## Pages & Columns

![ilustração de pages e columns](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/pages-and-columns-illustration.png)

Cada página tem até 3 colunas; cada coluna tem qualquer número de widgets. A primeira
página definida vira a home.

```nix
pages = [
  {
    name = "Home";
    columns = [ ... ];
  }
  {
    name = "Videos";
    columns = [ ... ];
  }
  {
    name = "Homelab";
    columns = [ ... ];
  }
];
```

### Propriedades da página

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| name | string | sim | |
| slug | string | não | |
| width | string | não | |
| desktop-navigation-width | string | não | |
| center-vertically | boolean | não | false |
| hide-desktop-navigation | boolean | não | false |
| show-mobile-header | boolean | não | false |
| head-widgets | array | não | |
| columns | array | sim | |

- `name` — nome mostrado na barra de navegação.
- `slug` — versão URL da página (ex.: `feeds`). Gerada do título se ausente.
- `width` — largura máxima no desktop: `default`, `slim` ou `wide`.
- `desktop-navigation-width` — largura máxima da navegação desktop (mesmos valores).
  Equivalências: `default` 1600px, `slim` 1100px, `wide` 1920px. Com `slim`, o máximo
  é 2 colunas.
- `center-vertically` — centraliza verticalmente o conteúdo.
- `hide-desktop-navigation` — esconde links de navegação no topo (desktop).
- `show-mobile-header` — mostra header com o nome da página no mobile.

![preview do mobile header](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/mobile-header-preview.png)

#### `head-widgets`

Widgets mostrados no topo da página, acima das colunas, ocupando a largura combinada:

![preview de head-widgets](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/head-widgets-preview.png)

```nix
pages = [
  {
    name = "Home";
    head-widgets = [
      {
        type = "markets";
        hide-header = true;
        markets = [
          { symbol = "SPY"; name = "S&P 500"; }
          { symbol = "BTC-USD"; name = "Bitcoin"; }
          { symbol = "NVDA"; name = "NVIDIA"; }
          { symbol = "AAPL"; name = "Apple"; }
          { symbol = "MSFT"; name = "Microsoft"; }
        ];
      }
    ];
    columns = [
      {
        size = "small";
        widgets = [ { type = "calendar"; } ];
      }
      {
        size = "full";
        widgets = [ { type = "hacker-news"; } ];
      }
      {
        size = "small";
        widgets = [
          {
            type = "weather";
            location = "London, United Kingdom";
          }
        ];
      }
    ];
  }
];
```

### Colunas

Dois tipos: `full` e `small`. Uma coluna `small` tem largura fixa (300px); `full` ocupa
o restante. Até 3 colunas por página, com 1 ou 2 colunas `full`.

```nix
columns = [
  { size = "small"; widgets = [ ... ]; }
  { size = "full"; widgets = [ ... ]; }
  { size = "small"; widgets = [ ... ]; }
];
```

| Nome | Tipo | Obrigatório |
| ---- | ---- | -------- |
| size | string | sim |
| widgets | array | não |

Configurações possíveis:

![colunas small-full-small](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/column-configuration-1.png)

```nix
columns = [
  { size = "small"; widgets = [ ... ]; }
  { size = "full"; widgets = [ ... ]; }
  { size = "small"; widgets = [ ... ]; }
];
```

![colunas full-small](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/column-configuration-2.png)

```nix
columns = [
  { size = "full"; widgets = [ ... ]; }
  { size = "small"; widgets = [ ... ]; }
];
```

![colunas full-full](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/column-configuration-3.png)

```nix
columns = [
  { size = "full"; widgets = [ ... ]; }
  { size = "full"; widgets = [ ... ]; }
];
```

## Widgets

Widgets são definidos na propriedade `widgets` de cada coluna:

```nix
widgets = [
  {
    type = "weather";
    location = "London, United Kingdom";
  }
];
```

### Propriedades compartilhadas

| Nome | Tipo | Obrigatório |
| ---- | ---- | -------- |
| type | string | sim |
| title | string | não |
| title-url | string | não |
| hide-header | boolean | não (false) |
| cache | string | não |
| css-class | string | não |

- `type` — tipo do widget.
- `title` — título; se vazio, é definido pelo widget.
- `title-url` — URL ao clicar no título.
- `hide-header` — esconde o header (título). Não funciona no widget `group`.
- `cache` — duração do cache em memória (`30s`, `5m`, `2h`, `1d`).
- `css-class` — classes CSS customizadas para a instância.

### RSS

Lista artigos de múltiplos feeds RSS.

```nix
{
  type = "rss";
  title = "News";
  style = "horizontal-cards";
  feeds = [
    { url = "https://feeds.bloomberg.com/markets/news.rss"; title = "Bloomberg"; }
    { url = "https://moxie.foxbusiness.com/google-publisher/markets.xml"; title = "Fox Business"; }
    { url = "https://moxie.foxbusiness.com/google-publisher/technology.xml"; title = "Fox Business"; }
  ];
}
```

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| style | string | não | vertical-list |
| feeds | array | sim | |
| thumbnail-height | float | não | 10 |
| card-height | float | não | 27 |
| limit | integer | não | 25 |
| preserve-order | boolean | não | false |
| single-line-titles | boolean | não | false |
| collapse-after | integer | não | 5 |

- `limit` — máximo de artigos a mostrar.
- `collapse-after` — artigos visíveis antes do botão "SHOW MORE". `-1` nunca recolhe.
- `preserve-order` — preserva a ordem dos artigos como nos feeds.
- `single-line-titles` — trunca títulos de mais de uma linha (só em `vertical-list`).
- `style` — `vertical-list`, `detailed-list`, `horizontal-cards`, `horizontal-cards-2`.
- `thumbnail-height` — altura das miniaturas (só `horizontal-cards`), em `rem`.
- `card-height` — altura dos cards (`horizontal-cards-2`), em `rem`.

`vertical-list`

![preview vertical-list](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/rss-feed-vertical-list-preview.png)

`detailed-list`

![preview detailed-list](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/rss-widget-detailed-list-preview.png)

`horizontal-cards`

![preview horizontal-cards](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/rss-feed-horizontal-cards-preview.png)

`horizontal-cards-2`

![preview horizontal-cards-2](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/rss-widget-horizontal-cards-2-preview.png)

#### Propriedades de cada feed

| Nome | Tipo | Obrigatório | Padrão | Notas |
| ---- | ---- | -------- | ------- | ----- |
| url | string | sim | | |
| title | string | não | título do feed | |
| hide-categories | boolean | não | false | só `detailed-list` |
| hide-description | boolean | não | false | só `detailed-list` |
| limit | integer | não | | |
| item-link-prefix | string | não | | |
| headers | chave/valor (string) | não | | |

```nix
feeds = [
  {
    url = "https://domain.com/rss";
    headers = {
      User-Agent = "Custom User Agent";
    };
  }
];
```

### Videos

Lista os últimos vídeos de canais do YouTube.

```nix
{
  type = "videos";
  channels = [
    "UCXuqSBlHAE6Xw-yeJA0Tunw"
    "UCBJycsmduvYEL83R_U4JriQ"
    "UCHnyfMqiRRG1u-2MsSQLbXA"
  ];
}
```

![preview videos](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/videos-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| channels | array | sim | |
| playlists | array | não | |
| limit | integer | não | 25 |
| style | string | não | horizontal-cards |
| collapse-after | integer | não | 7 |
| collapse-after-rows | integer | não | 4 |
| include-shorts | boolean | não | false |
| video-url-template | string | não | https://www.youtube.com/watch?v={VIDEO-ID} |

- `channels` — lista de IDs de canais.

Uma forma de obter o ID de um canal é ir à página do canal e clicar na descrição:

![exemplo de descrição do canal](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/videos-channel-description-example.png)

Depois role até "Share channel" e clique em "Copy channel ID":

![copiar ID do canal](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/videos-copy-channel-id-example.png)

- `playlists` — lista de IDs de playlists:

```nix
playlists = [
  "PL8mG-RkN2uTyZZ00ObwZxxoG_nJbs3qec"
  "PL8mG-RkN2uTxTK4m_Vl2dYR9yE41kRdBg"
];
```

- `style` — `horizontal-cards`, `vertical-list` ou `grid-cards`.

![preview vertical-list](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/videos-widget-vertical-list-preview.png)

![preview grid-cards](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/videos-widget-grid-cards-preview.png)

- `video-url-template` — substitui o link padrão dos vídeos (útil com front-end próprio):

```nix
video-url-template = "https://invidious.your-domain.com/watch?v={VIDEO-ID}";
```

### Hacker News

```nix
{
  type = "hacker-news";
  limit = 15;
  collapse-after = 5;
}
```

![preview hacker-news](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/hacker-news-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| limit | integer | não | 15 |
| collapse-after | integer | não | 5 |
| comments-url-template | string | não | https://news.ycombinator.com/item?id={POST-ID} |
| sort-by | string | não | top |
| extra-sort-by | string | não | |

- `comments-url-template` — substitui o link dos comentários:

```nix
comments-url-template = "https://www.hckrnws.com/stories/{POST-ID}";
```

- `sort-by` — `top`, `new` ou `best`.
- `extra-sort-by` — única opção: `engagement`.

### Lobsters

```nix
{
  type = "lobsters";
  sort-by = "hot";
  tags = [ "go" "security" "linux" ];
  limit = 15;
  collapse-after = 5;
}
```

![preview lobsters](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/lobsters-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| instance-url | string | não | https://lobste.rs/ |
| custom-url | string | não | |
| limit | integer | não | 15 |
| collapse-after | integer | não | 5 |
| sort-by | string | não | hot |
| tags | array | não | |

- `instance-url` — URL base de outra instância.
- `custom-url` — se definida, ignora `instance-url`, `sort-by` e `tags`.
- `sort-by` — `hot` ou `new`.
- `tags` — filtra por tags (sem ordem customizada; usa `hot`).

### Reddit

> **Aviso:** o Reddit bloqueia acesso não autenticado de IPs de VPS (403). Use
> `app-auth`, `proxy` ou VPN.

```nix
{
  type = "reddit";
  subreddit = "technology";
}
```

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| subreddit | string | sim |  |
| style | string | não | vertical-list |
| show-thumbnails | boolean | não | false |
| show-flairs | boolean | não | false |
| limit | integer | não | 15 |
| collapse-after | integer | não | 5 |
| comments-url-template | string | não | https://www.reddit.com/{POST-PATH} |
| request-url-template | string | não |  |
| proxy | string ou mapa | não |  |
| sort-by | string | não | hot |
| top-period | string | não | day |
| search | string | não | |
| extra-sort-by | string | não | |
| app-auth | objeto | não | |

- `style` — `vertical-list`, `horizontal-cards` (colunas `full`) ou `vertical-cards` (colunas `small`).

![preview vertical-list](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/reddit-widget-preview.png)

![preview horizontal-cards](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/reddit-widget-horizontal-cards-preview.png)

![preview vertical-cards](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/reddit-widget-vertical-cards-preview.png)

![preview vertical-list com thumbnails](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/reddit-widget-vertical-list-thumbnails.png)

- `comments-url-template` — substitui o link dos comentários:

```nix
comments-url-template = "https://old.reddit.com/{POST-PATH}";
```

- `request-url-template` — URL customizada para rotear a requisição:

```nix
request-url-template = "https://your.proxy/?url={REQUEST-URL}";
```

- `proxy` — proxy HTTP/HTTPS:

```nix
proxy = "http://user:pass@proxy.com:8080";
# ou com opções:
proxy = {
  url = "http://proxy.com:8080";
  allow-insecure = true;
  timeout = "10s";
};
```

- `sort-by` — `hot`, `new`, `top`, `rising`.
- `top-period` — só com `sort-by = "top"`: `hour`, `day`, `week`, `month`, `year`, `all`.
- `search` — palavras-chave (pesquisa em campos específicos).

![pesquisa por campo no reddit](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/reddit-field-search.png)

- `extra-sort-by` — única opção: `engagement`.
- `app-auth` — autenticação via app registrado:

```nix
{
  type = "reddit";
  subreddit = "technology";
  app-auth = {
    name = "''${REDDIT_APP_NAME}";
    id = "''${REDDIT_APP_CLIENT_ID}";
    secret = "''${REDDIT_APP_SECRET}";
  };
}
```

### Search

Barra de busca em vários mecanismos.

```nix
{
  type = "search";
  search-engine = "duckduckgo";
  bangs = [
    { title = "YouTube"; shortcut = "!yt"; url = "https://www.youtube.com/results?search_query={QUERY}"; }
  ];
}
```

![preview search](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/search-widget-preview.png)

#### Atalhos de teclado

| Teclas | Ação |
| ---- | ------ |
| <kbd>S</kbd> | Focar a barra |
| <kbd>Enter</kbd> | Buscar na mesma aba |
| <kbd>Ctrl</kbd>+<kbd>Enter</kbd> | Buscar em nova aba |
| <kbd>Escape</kbd> | Sair do foco |
| <kbd>Up</kbd> | Inserir última busca |

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| search-engine | string | não | duckduckgo |
| new-tab | boolean | não | false |
| autofocus | boolean | não | false |
| target | string | não | _blank |
| placeholder | string | não | Type here to search… |
| bangs | array | não | |

- `search-engine` — um valor da tabela ou URL customizada (com `{QUERY}`):

| Nome | URL |
| ---- | --- |
| duckduckgo | `https://duckduckgo.com/?q={QUERY}` |
| google | `https://www.google.com/search?q={QUERY}` |
| bing | `https://www.bing.com/search?q={QUERY}` |
| perplexity | `https://www.perplexity.ai/search?q={QUERY}` |
| kagi | `https://kagi.com/search?q={QUERY}` |
| startpage | `https://www.startpage.com/search?q={QUERY}` |

- `bangs` — [bangs](https://duckduckgo.com/bangs) (atalhos de busca):

```nix
bangs = [
  { shortcut = "!r"; url = "https://www.reddit.com/search?q={QUERY}"; }
];
```

![preview bangs](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/search-widget-bangs-preview.png)

### Group

Agrupa widgets em abas. Não é permitido aninhar `group` ou `split-column` dentro de `group`.

```nix
{
  type = "group";
  widgets = [
    { type = "reddit"; subreddit = "gamingnews"; show-thumbnails = true; collapse-after = 6; }
    { type = "reddit"; subreddit = "games"; }
    { type = "reddit"; subreddit = "pcgaming"; show-thumbnails = true; }
  ];
}
```

![preview group](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/group-widget-preview.png)

#### Compartilhando propriedades (âncoras YAML → `let`)

No YAML usam-se âncoras (`&shared-properties` / `<<: *shared-properties`). Em Nix, use
`let ... in`:

```nix
let
  sharedProperties = {
    type = "reddit";
    show-thumbnails = true;
    collapse-after = 6;
  };
in
{
  type = "group";
  widgets = [
    (sharedProperties // { subreddit = "gamingnews"; })
    (sharedProperties // { subreddit = "games"; })
    (sharedProperties // { subreddit = "pcgaming"; })
  ];
}
```

### Split Column

Divide uma coluna `full` ao meio, colocando widgets lado a lado. No mobile (ou sem
largura) vira uma coluna só. Você pode inserir `group` dentro de `split-column`, mas não
`split-column` dentro de `group`.

```nix
{
  type = "split-column";
  widgets = [
    { type = "hacker-news"; collapse-after = 3; }
    { type = "lobsters"; collapse-after = 3; }
  ];
}
```

![preview split-column](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/split-column-widget-preview.png)

Layout de 3 colunas iguais (`max-columns: 3`):

![split-column 3 colunas](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/split-column-widget-3-columns.png)

```nix
pages = [
  {
    name = "Home";
    columns = [
      {
        size = "full";
        widgets = [
          {
            type = "split-column";
            max-columns = 3;
            widgets = [
              { type = "reddit"; subreddit = "selfhosted"; collapse-after = 15; }
              { type = "reddit"; subreddit = "homelab"; collapse-after = 15; }
              { type = "reddit"; subreddit = "sysadmin"; collapse-after = 15; }
            ];
          }
        ];
      }
    ];
  }
];
```

Layout de 4 colunas iguais (com `width = "wide"`):

![split-column 4 colunas](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/split-column-widget-4-columns.png)

```nix
pages = [
  {
    name = "Home";
    width = "wide";
    columns = [
      {
        size = "full";
        widgets = [
          {
            type = "split-column";
            max-columns = 4;
            widgets = [
              { type = "reddit"; subreddit = "selfhosted"; collapse-after = 15; }
              { type = "reddit"; subreddit = "homelab"; collapse-after = 15; }
              { type = "reddit"; subreddit = "linux"; collapse-after = 15; }
              { type = "reddit"; subreddit = "sysadmin"; collapse-after = 15; }
            ];
          }
        ];
      }
    ];
  }
];
```

Layout masonry (até 5 colunas, `width = "wide"`), reaproveitando propriedades com `let`:

![split-column masonry](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/split-column-widget-masonry.png)

```nix
let
  subreddit = name: {
    type = "reddit";
    collapse-after = 5;
    subreddit = name;
  };
in
pages = [
  {
    name = "Home";
    width = "wide";
    columns = [
      {
        size = "full";
        widgets = [
          {
            type = "split-column";
            max-columns = 5;
            widgets = map subreddit [
              "selfhosted" "homelab" "linux" "sysadmin" "DevOps"
              "Networking" "DataHoarding" "OpenSource" "Privacy" "FreeSoftware"
            ];
          }
        ];
      }
    ];
  }
];
```

### Custom API

Exibe dados de uma API JSON usando um template customizado (Go `html/template` + gjson).

![preview custom-api 1](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/custom-api-preview-1.png)

```nix
{
  type = "custom-api";
  title = "Random Fact";
  cache = "6h";
  url = "https://uselessfacts.jsph.pl/api/v2/facts/random";
  template = ''
    <p class="size-h4 color-paragraph">{{ .JSON.String "text" }}</p>
  '';
}
```

![preview custom-api 2](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/custom-api-preview-2.png)

```nix
{
  type = "custom-api";
  title = "Immich stats";
  cache = "1d";
  url = "https://''${IMMICH_URL}/api/server/statistics";
  headers = {
    x-api-key = "''${IMMICH_API_KEY}";
    Accept = "application/json";
  };
  template = ''
    <div class="flex justify-between text-center">
      <div>
          <div class="color-highlight size-h3">{{ .JSON.Int "photos" | formatNumber }}</div>
          <div class="size-h6">PHOTOS</div>
      </div>
      <div>
          <div class="color-highlight size-h3">{{ .JSON.Int "videos" | formatNumber }}</div>
          <div class="size-h6">VIDEOS</div>
      </div>
      <div>
          <div class="color-highlight size-h3">{{ div (.JSON.Int "usage" | toFloat) 1073741824 | toInt | formatNumber }}GB</div>
          <div class="size-h6">USAGE</div>
      </div>
    </div>
  '';
}
```

![preview custom-api 3](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/custom-api-preview-3.png)

```nix
{
  type = "custom-api";
  title = "Steam Specials";
  cache = "12h";
  url = "https://store.steampowered.com/api/featuredcategories?cc=us";
  template = ''
    <ul class="list list-gap-10 collapsible-container" data-collapse-after="5">
    {{ range .JSON.Array "specials.items" }}
      <li>
        <a class="size-h4 color-highlight block text-truncate" href="https://store.steampowered.com/app/{{ .Int "id" }}/">{{ .String "name" }}</a>
        <ul class="list-horizontal-text">
          <li>{{ div (.Int "final_price" | toFloat) 100 | printf "$%.2f" }}</li>
          {{ $discount := .Int "discount_percent" }}
          <li{{ if ge $discount 40 }} class="color-positive"{{ end }}>{{ $discount }}% off</li>
        </ul>
      </li>
    {{ end }}
    </ul>
  '';
}
```

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| url | string | não | |
| headers | chave/valor (string) | não | |
| method | string | não | GET |
| body-type | string | não | json |
| body | qualquer | não | |
| basic-auth | mapa | não | |
| frameless | boolean | não | false |
| allow-insecure | boolean | não | false |
| skip-json-validation | boolean | não | false |
| template | string | sim | |
| options | mapa | não | |
| parameters | chave/valor | não | |
| subrequests | mapa de requests | não | |

- `method` — `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `OPTIONS`, `HEAD`.
- `body-type` — `json` ou `string`.
- `body` — corpo da requisição:

```nix
body-type = "json";
body = {
  key1 = "value1";
  key2 = "value2";
  multiple-items = [ "item1" "item2" ];
};
```

- `basic-auth` — autenticação HTTP básica:

```nix
basic-auth = {
  username = "your-username";
  password = "your-password";
};
```

- `options` — mapa de opções passadas ao template (`StringOr`, `IntOr`, `BoolOr`, `FloatOr`).
- `parameters` — parâmetros de query:

```nix
parameters = {
  param1 = "value1";
  param2 = [ "item1" "item2" ];
};
```

- `subrequests` — requests adicionais executadas em paralelo, acessíveis no template:

```nix
{
  type = "custom-api";
  cache = "2h";
  subrequests = {
    another-one = { url = "https://uselessfacts.jsph.pl/api/v2/facts/random"; };
  };
  title = "Random Fact";
  url = "https://uselessfacts.jsph.pl/api/v2/facts/random";
  template = ''
    <p class="size-h4 color-paragraph">{{ .JSON.String "text" }}</p>
    <p class="size-h4 color-paragraph margin-top-15">{{ (.Subrequest "another-one").JSON.String "text" }}</p>
  '';
}
```

### Extension

Widget fornecido por fonte externa (3ª parte).

```nix
{
  type = "extension";
  url = "https://domain.com/widget/display-a-message";
  allow-potentially-dangerous-html = true;
  parameters = {
    message = "Hello, world!";
  };
}
```

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| url | string | sim | |
| fallback-content-type | string | não | |
| allow-potentially-dangerous-html | boolean | não | false |
| headers | chave/valor | não | |
| parameters | chave/valor | não | |

> **Aviso:** `allow-potentially-dangerous-html` permite HTML de extensão. Só habilite
> se você confia absolutamente na URL da extensão.

### Weather

Informações do tempo (dados de https://open-meteo.com/).

```nix
{
  type = "weather";
  units = "metric";
  hour-format = "12h";
  location = "London, United Kingdom";
}
```

![preview weather](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/weather-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| location | string | sim |  |
| units | string | não | metric |
| hour-format | string | não | 12h |
| hide-location | boolean | não | false |
| show-area-name | boolean | não | false |

- `location` — cidade e país. Cidades dos EUA com nomes comuns podem incluir o estado
  como segundo parâmetro (ex.: `Greenville, North Carolina, United States`).
- `units` — `metric` ou `imperial`.
- `hour-format` — `12h` ou `24h`.
- `show-area-name` — exibe estado/área administrativa no nome.

### Todo

Lista de tarefas (armazenada no localStorage do navegador).

```nix
{ type = "to-do"; }
```

![preview todo](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/todo-widget-preview.png)

Para reordenar, arraste pela parte superior da tarefa:

![reordenar tarefas](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/reorder-todo-tasks-preview.gif)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| id | string | não | |

- `id` — identifica a lista (para ter múltiplas listas independentes).

### Monitor

Mostra se sites estão online (GET; 200 = OK) e o tempo de resposta.

```nix
{
  type = "monitor";
  cache = "1m";
  title = "Services";
  sites = [
    { title = "Jellyfin"; url = "https://jellyfin.yourdomain.com"; icon = "/assets/jellyfin-logo.png"; }
    { title = "Gitea"; url = "https://gitea.yourdomain.com"; icon = "/assets/gitea-logo.png"; }
    { title = "Immich"; url = "https://immich.yourdomain.com"; icon = "/assets/immich-logo.png"; }
    { title = "AdGuard Home"; url = "https://adguard.yourdomain.com"; icon = "/assets/adguard-logo.png"; }
    { title = "Vaultwarden"; url = "https://vault.yourdomain.com"; icon = "/assets/vaultwarden-logo.png"; }
  ];
}
```

![preview monitor](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/monitor-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| sites | array | sim | |
| style | string | não | |
| show-failing-only | boolean | não | false |

- `style` — `compact`:

![preview monitor compact](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/monitor-widget-compact-preview.png)

#### Propriedades de cada site

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| title | string | sim | |
| url | string | sim | |
| check-url | string | não | |
| error-url | string | não | |
| icon | string | não | |
| timeout | string | não | 3s |
| allow-insecure | boolean | não | false |
| same-tab | boolean | não | false |
| alt-status-codes | array | não | |
| basic-auth | objeto | não | |

```nix
{
  title = "Protected";
  url = "https://service.domain.com";
  alt-status-codes = [ 403 ];
  basic-auth = {
    username = "your-username";
    password = "your-password";
  };
}
```

### Releases

Últimos releases de repositórios no GitHub, GitLab, Codeberg ou Docker Hub.

```nix
{
  type = "releases";
  show-source-icon = true;
  repositories = [
    "go-gitea/gitea"
    "jellyfin/jellyfin"
    "glanceapp/glance"
    "codeberg:redict/redict"
    "gitlab:fdroid/fdroidclient"
    "dockerhub:gotify/server"
  ];
}
```

![preview releases](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/releases-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| repositories | array | sim |  |
| show-source-icon | boolean | não | false |
| token | string | não | |
| gitlab-token | string | não | |
| limit | integer | não | 10 |
| collapse-after | integer | não | 5 |

- `repositories` — prefixos para outros hosts e tags do Docker Hub:

```nix
repositories = [
  "gitlab:inkscape/inkscape"
  "dockerhub:glanceapp/glance"
  "codeberg:redict/redict"
  "dockerhub:nginx:latest"
];
```

Incluir prereleases (só GitHub) via objeto:

```nix
repositories = [
  "gitlab:inkscape/inkscape"
  { repository = "glanceapp/glance"; include-prereleases = true; }
  "codeberg:redict/redict"
];
```

- `token` — token read-only do GitHub para evitar o limite de 60 req/h:

```nix
token = "''${GITHUB_TOKEN}";
```

### Docker Containers

Status dos containers Docker (com ícone e descrição).

![preview docker-containers](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/docker-containers-preview.png)

```nix
{
  type = "docker-containers";
  hide-by-default = false;
}
```

> **Nota:** o widget requer acesso ao `docker.sock`. O módulo NixOS roda com
> `DynamicUser`, então pode ser necessário dar acesso ao socket ou usar um socket
> remoto/proxy (veja `sock-path`).

Configuração via labels dos containers (`glance.*`) ou direto na config:

```nix
{
  type = "docker-containers";
  containers = {
    container_name_1 = {
      name = "Container Name";
      description = "Description of the container";
      url = "https://container.domain.com";
      icon = "si:container-icon";
      hide = false;
    };
  };
}
```

Para agrupar serviços com múltiplos containers, use `glance.id` no principal e
`glance.parent` nos filhos:

![container pai](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/docker-container-parent.png)

![container pai 2](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/docker-container-parent2.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| hide-by-default | boolean | não | false |
| format-container-names | boolean | não | false |
| sock-path | string | não | /var/run/docker.sock |
| category | string | não | |
| running-only | boolean | não | false |

- `hide-by-default` — esconde containers por padrão; exiba com label `glance.hide: false`.
- `format-container-names` — converte `container_name_1` em `Container Name 1`.
- `sock-path` — caminho do socket (Unix) ou remoto (`tcp://`, `http://`).
- `category` — filtra por `glance.category`.
- `running-only` — mostra apenas containers rodando.

#### Labels

| Nome | Descrição |
| ---- | ----------- |
| glance.name | Nome exibido na UI |
| glance.icon | Ícone (veja [Ícones](#icones)) |
| glance.url | URL ao clicar no container |
| glance.same-tab | Abrir na mesma aba (padrão false) |
| glance.description | Descrição curta |
| glance.hide | Esconder o container |
| glance.id | ID customizado (agrupamento) |
| glance.parent | ID do container pai (agrupamento) |
| glance.category | Categoria (filtro) |

### DNS Stats

Estatísticas de um DNS com bloqueio de anúncios (AdGuard Home, Pi-hole ou Technitium).

```nix
{
  type = "dns-stats";
  service = "adguard";
  url = "https://adguard.domain.com/";
  username = "admin";
  password = "''${ADGUARD_PASSWORD}";
}
```

![preview dns-stats](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/dns-stats-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| service | string | não | pihole |
| allow-insecure | boolean | não | false |
| url | string | sim |  |
| username | string | quando `adguard` |  |
| password | string | quando `adguard`/`pihole-v6` |  |
| token | string | quando `pihole` |  |
| hide-graph | boolean | não | false |
| hide-top-domains | boolean | não | false |
| hour-format | string | não | 12h |

- `service` — `adguard`, `technitium`, `pihole` (v5-) ou `pihole-v6` (v6+).

### Server Stats

Estatísticas de CPU, memória e disco (local ou remota).

```nix
{
  type = "server-stats";
  servers = [
    { type = "local"; name = "Services"; }
  ];
}
```

![preview server-stats](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/server-stats-preview.gif)

> **Nota:** para servidores remotos é preciso o
> [Glance Agent](https://github.com/glanceapp/agent). Acima de 80°C, um ícone de chama
> aparece ao lado da CPU:

![flame icon](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/server-stats-flame-icon.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| servers | array | não |  |

##### Comuns a `local` e `remote`

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| type | string | sim |  |
| name | string | não |  |
| hide-swap | boolean | não | false |

##### Servidor `local`

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| cpu-temp-sensor | string | não |  |
| hide-mountpoints-by-default | boolean | não | false |
| mountpoints | mapa | não |  |

```nix
servers = [
  {
    type = "local";
    hide-mountpoints-by-default = true;
    mountpoints = {
      "/" = { hide = false; };
      "/mnt/data" = { hide = false; };
    };
  }
];
```

##### Servidor `remote`

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| url | string | sim |  |
| token | string | não |  |
| timeout | string | não | 3s |

### Repository

Informações de um repositório + últimos PRs e issues abertas.

```nix
{
  type = "repository";
  repository = "glanceapp/glance";
  pull-requests-limit = 5;
  issues-limit = 3;
  commits-limit = 3;
}
```

![preview repository](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/repository-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| repository | string | sim |  |
| token | string | não | |
| pull-requests-limit | integer | não | 3 |
| issues-limit | integer | não | 3 |
| commits-limit | integer | não | -1 |

- `token` — token read-only do GitHub.
- `*-limit` — `-1` para não mostrar.

### Bookmarks

Lista de links, agrupáveis.

```nix
{
  type = "bookmarks";
  groups = [
    {
      links = [
        { title = "Gmail"; url = "https://mail.google.com/mail/u/0/"; }
        { title = "Amazon"; url = "https://www.amazon.com/"; }
        { title = "Github"; url = "https://github.com/"; }
        { title = "Wikipedia"; url = "https://en.wikipedia.org/"; }
      ];
    }
    {
      title = "Entertainment";
      color = "10 70 50";
      links = [
        { title = "Netflix"; url = "https://www.netflix.com/"; }
        { title = "Disney+"; url = "https://www.disneyplus.com/"; }
        { title = "YouTube"; url = "https://www.youtube.com/"; }
        { title = "Prime Video"; url = "https://www.primevideo.com/"; }
      ];
    }
    {
      title = "Social";
      color = "200 50 50";
      links = [
        { title = "Reddit"; url = "https://www.reddit.com/"; }
        { title = "Twitter"; url = "https://twitter.com/"; }
        { title = "Instagram"; url = "https://www.instagram.com/"; }
      ];
    }
  ];
}
```

![preview bookmarks](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/bookmarks-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório |
| ---- | ---- | -------- |
| groups | array | sim |

##### Propriedades de cada grupo

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| title | string | não | |
| color | HSL | não | cor primária do tema |
| links | array | sim | |
| same-tab | boolean | não | false |
| hide-arrow | boolean | não | false |
| target | string | não | |

##### Propriedades de cada link

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| title | string | sim | |
| url | string | sim | |
| description | string | não | |
| icon | string | não | |
| same-tab | boolean | não | false |
| hide-arrow | boolean | não | false |
| target | string | não | |

- `icon` — veja [Ícones](#icones).
- `target` — `_blank`, `_self`, `_parent`, `_top` (tem precedência sobre `same-tab`).

### Calendar

```nix
{
  type = "calendar";
  first-day-of-week = "monday";
}
```

![preview calendar](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/calendar-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| first-day-of-week | string | não | monday |

### Calendar (legacy)

> **Depreciado** e pode ser removido em versões futuras.

```nix
{
  type = "calendar-legacy";
  start-sunday = false;
}
```

![preview calendar-legacy](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/calendar-legacy-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| start-sunday | boolean | não | false |

### ChangeDetection.io

Lista watches do changedetection.io.

```nix
{
  type = "change-detection";
  instance-url = "https://changedetection.mydomain.com/";
  token = "''${CHANGE_DETECTION_TOKEN}";
}
```

![preview change-detection](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/change-detection-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| instance-url | string | não | https://www.changedetection.io |
| token | string | não |  |
| limit | integer | não | 10 |
| collapse-after | integer | não | 5 |
| watches | array de strings | não |  |

```nix
watches = [
  "1abca041-6d4f-4554-aa19-809147f538d3"
  "705ed3e4-ea86-4d25-a064-822a6425be2c"
];
```

### Clock

Relógio com hora/data (e fusos opcionais).

```nix
{
  type = "clock";
  hour-format = "24h";
  timezones = [
    { timezone = "Europe/Paris"; label = "Paris"; }
    { timezone = "America/New_York"; label = "New York"; }
    { timezone = "Asia/Tokyo"; label = "Tokyo"; }
  ];
}
```

![preview clock](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/clock-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| hour-format | string | não | 24h |
| timezones | array | não |  |

- `hour-format` — `12h` ou `24h`.

#### Propriedades de cada timezone

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| timezone | string | sim | |
| label | string | não | |

### Markets

Lista de mercados, valor atual, variação do dia e gráfico de 21d (Yahoo Finance).

```nix
{
  type = "markets";
  markets = [
    { symbol = "SPY"; name = "S&P 500"; }
    { symbol = "BTC-USD"; name = "Bitcoin"; chart-link = "https://www.tradingview.com/chart/?symbol=INDEX:BTCUSD"; }
    { symbol = "NVDA"; name = "NVIDIA"; }
    { symbol = "AAPL"; symbol-link = "https://www.google.com/search?tbm=nws&q=apple"; name = "Apple"; }
  ];
}
```

![preview markets](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/markets-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório |
| ---- | ---- | -------- |
| markets | array | sim |
| sort-by | string | não |
| chart-link-template | string | não |
| symbol-link-template | string | não |

- `sort-by` — `change` ou `absolute-change`.
- `chart-link-template` / `symbol-link-template` — template de link com `{SYMBOL}`:

```nix
chart-link-template = "https://www.tradingview.com/chart/?symbol={SYMBOL}";
symbol-link-template = "https://www.google.com/search?tbm=nws&q={SYMBOL}";
```

##### Propriedades de cada mercado

| Nome | Tipo | Obrigatório |
| ---- | ---- | -------- |
| symbol | string | sim |
| name | string | não |
| symbol-link | string | não |
| chart-link | string | não |

### Twitch Channels

```nix
{
  type = "twitch-channels";
  channels = [
    "jembawls"
    "giantwaffle"
    "asmongold"
    "cohhcarnage"
    "j_blow"
    "xQc"
  ];
}
```

![preview twitch-channels](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/twitch-channels-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| channels | array | sim | |
| collapse-after | integer | não | 5 |
| sort-by | string | não | viewers |

- `sort-by` — `viewers` ou `live`.

### Twitch top games

```nix
{
  type = "twitch-top-games";
  exclude = [
    "just-chatting"
    "pools-hot-tubs-and-beaches"
    "music"
    "art"
    "asmr"
  ];
}
```

![preview twitch-top-games](https://raw.githubusercontent.com/glanceapp/glance/main/docs/images/twitch-top-games-widget-preview.png)

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| exclude | array | não | |
| limit | integer | não | 10 |
| collapse-after | integer | não | 5 |

- `exclude` — slugs de categorias que nunca serão mostradas.

### iframe

```nix
{
  type = "iframe";
  source = "<url>";
  height = 400;
}
```

#### Propriedades

| Nome | Tipo | Obrigatório | Padrão |
| ---- | ---- | -------- | ------- |
| source | string | sim | |
| height | integer | não | 300 |

- `height` — altura do iframe (mínimo 50).

### HTML

```nix
{
  type = "html";
  source = ''
    <p>Hello, <span class="color-primary">World</span>!</p>
  '';
}
```
