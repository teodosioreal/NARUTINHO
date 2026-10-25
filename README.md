# Naruto 5 Online 🍥

Naruto Shippuden: Ultimate Ninja 5 (versão BR dublada) rodando numa VPS e jogado **pelo navegador**, com **salas** e **todos os personagens liberados**.

O jogo roda no servidor (PCSX2). Você e seus amigos abrem o site no Chrome/Edge, escolhem uma sala e jogam com controle, sem instalar nada.

```
                    ┌─ Sala 1 (PCSX2) ─► Jogador 1 + Jogador 2 + quem quiser assistir
Página de entrada ──┼─ Sala 2 (PCSX2) ─► Jogador 1 + Jogador 2 + quem quiser assistir
 (HTTPS + senha)    └─ ...
```

> ⚠️ A ISO do jogo, a BIOS do PS2 e o memory card **não ficam neste repositório**. Eles vão direto do seu PC para a VPS. Mantenha o site com senha e só para seus amigos.

## O que vem pronto

- **Salas**: cada sala é um PS2 separado, com seu próprio Jogador 1, Jogador 2 e espectadores. A página de entrada lista as salas com os botões **Jogador 1**, **Jogador 2** e **Assistir**.
- **Todos os personagens liberados**: `ferramentas/liberar_personagens.py` grava os códigos do CodeMasters Project direto no executável da ISO (`201E94B4 24020003` e `201E95AC 2402FFFF`). Ele confere os bytes antes e não altera nada se a versão do jogo for outra.
- **Save completo** (opcional): se existir `save/Mcd001.ps2`, cada sala começa com esse memory card. O progresso de cada sala é separado.
- **Chat de voz** na página de entrada: cada um coloca o fone, entra na voz da sua sala (ou na voz geral) e conversa enquanto joga, com indicador de quem está falando, botão de mutar e volume por pessoa. O áudio vai direto entre os navegadores, e um servidor TURN na própria VPS garante a conexão mesmo em 4G ou internet com CGNAT.
- **Direto para a luta**: dá para salvar o momento da tela de seleção do versus como ponto de partida de todas as salas (veja *Começar direto no versus*).
- **PCSX2 já configurado**: abre o jogo sozinho em tela cheia, com renderizador por CPU (VPS sem placa de vídeo) e controles dos jogadores 1 e 2 já mapeados. Os atalhos de teclado do PCSX2 ficam desligados, então ninguém fecha o jogo ou abre menu sem querer.
- **HTTPS de verdade e senha** pelo Caddy, com endereço grátis `IP.sslip.io` e salas em `sala1.IP.sslip.io`, `sala2...` (sem precisar comprar domínio).
- **Navegador protegido**: ninguém abre terminal, arquivos ou sudo pela página.

## Instalação (do seu Windows)

1. Crie a VPS com **Ubuntu 24.04** (veja a recomendação abaixo) e anote o **IP** e a **senha de root**.
2. Dê dois cliques em **`ENVIAR_PARA_VPS.bat`** e informe o IP.
   - Ele baixa este repositório na VPS, envia a BIOS, o memory card e a ISO (2 GB, demora) e roda o instalador.
3. O instalador pergunta o **usuário**, a **senha do site** e **quantas salas** criar. No fim, mostra os links.

Para instalar manualmente na VPS:

```bash
git clone https://github.com/teodosioreal/NARUTINHO.git /opt/naruto5
# ISO em /opt/naruto5/jogo/, BIOS (.bin) em /opt/naruto5/bios/, memory card (opcional) em /opt/naruto5/save/Mcd001.ps2
sudo bash /opt/naruto5/instalar.sh
```

Para mudar o número de salas depois, é só rodar `sudo bash instalar.sh` de novo.

Com domínio próprio, aponte o domínio **e** `*.seudominio` (wildcard) para o IP da VPS.

### VPS que já tem um site (modo teste)

Se as portas 80/443 já estiverem em uso (nginx, Apache, painel), o instalador **não mexe no seu site**. Ele entra no modo teste: a página de entrada fica em `https://IP:8443` e as salas em `:8444`, `:8445`... O navegador vai avisar que o site "não é seguro": clique em **Avançado > Continuar**.

## Como jogar

1. Abra a página de entrada e entre com usuário e senha.
2. Combinem quem fica em cada sala. Um clica em **Jogador 1** e o outro em **Jogador 2**. Os demais podem clicar em **Assistir**.
3. Cada sala pede a senha de novo (é a mesma).
4. Conecte o controle e aperte um botão com a página da sala aberta.

O Jogador 2 precisa de um **controle** (USB ou Bluetooth, de Xbox ou PlayStation). O Jogador 1 pode usar controle ou teclado:

| PS2 | Tecla | PS2 | Tecla |
|---|---|---|---|
| Direcional | Setas ou WASD | Start | Enter |
| ✕ | K | Select | Backspace |
| ○ | L | L1 / R1 | Q / E |
| □ | J | L2 / R2 | 1 / 3 |
| △ | I | | |

## Chat de voz

1. Na página de entrada, digite seu nome e clique em **🎧 Voz** na sua sala (ou em **Voz geral**).
2. Permita o microfone quando o navegador pedir.
3. Abra a sala do jogo, que abre em outra aba. **Deixe a aba da página de entrada aberta** para continuar falando e ouvindo.

Use **fone de ouvido**: sem fone, o som do jogo vaza para o microfone. São no máximo 8 pessoas por voz.

## Começar direto no versus

Para as salas já abrirem na tela de seleção de personagens, sem abertura nem menus:

1. Abra a **Sala 1** e vá até a tela de seleção de personagens do versus.
2. Na VPS, rode:
   ```bash
   cd /opt/naruto5 && sudo bash ferramentas/sala.sh inicio
   ```
   Isso salva esse momento e copia para todas as salas.

Depois disso:
- `sudo bash ferramentas/sala.sh reiniciar 2` volta a sala 2 para a seleção de personagens na hora (útil se alguém se perder nos menus).
- `sudo bash ferramentas/sala.sh tirar-inicio` desfaz, e as salas voltam a abrir do zero.

## VPS recomendada

Cada sala é um PS2 inteiro rodando na CPU, mais a codificação do vídeo. A conta é **cerca de 4 vCPUs e 2 GB de RAM por sala**.

| Salas | vCPU | RAM |
|---|---|---|
| 1 | 4 | 8 GB |
| 2 | 8 | 16 GB |
| 3 | 12 | 16 GB |

Escolha um datacenter em **São Paulo**, para ter pouco atraso no controle para quem está no Brasil, com **Ubuntu 24.04**.

## Comandos úteis (na VPS)

```bash
cd /opt/naruto5
docker compose restart sala1   # reinicia a sala 1
docker compose logs -f sala1   # ver o que está acontecendo na sala 1
docker compose down            # desligar tudo
docker compose up -d           # ligar tudo
rm .configurado && sudo bash instalar.sh   # trocar usuário/senha
```

Os saves de cada sala ficam em `config/salaN/.config/PCSX2/memcards/`.

## Problemas comuns

- **Jogo lento / som picotando**: CPU fraca para o número de salas. Diminua as salas ou use uma VPS maior.
- **Tela preta**: rode `docker compose logs sala1`. Se aparecer erro de *seccomp*, adicione `security_opt: [seccomp:unconfined]` em `x-sala` no `instalar.sh` e rode o instalador de novo.
- **Erro de certificado ou site não abre**: confira se as portas 80 e 443 estão liberadas no firewall do painel da VPS.
- **Voz conecta mas ninguém se ouve** (fica em "conectando..." ou "sem conexão"): libere 3478 (TCP e UDP) e 49160-49200 (UDP) no firewall do painel da VPS.
- **Controle do Jogador 2 não funciona**: ele precisa entrar pelo botão **Jogador 2** e apertar um botão do controle com a página em foco.
