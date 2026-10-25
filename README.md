# Naruto 5 Online 🍥

Naruto Shippuden: Ultimate Ninja 5 (versão BR dublada) rodando numa VPS e jogado **pelo navegador**, com **todos os personagens liberados**.

O jogo roda no servidor (PCSX2). Você e seus amigos abrem um link no Chrome/Edge, digitam a senha e jogam com controle, sem instalar nada.

```
VPS: PCSX2 + Selkies + Caddy (HTTPS + senha)  ──►  navegador do jogador 1 (você)
                                               ──►  navegador do jogador 2 (amigo, link de Player 2)
```

> ⚠️ A ISO do jogo e a BIOS do PS2 **não ficam neste repositório**. Elas vão direto do seu PC para a VPS. Mantenha o site com senha e só para seus amigos.

## O que vem pronto

- **Todos os personagens liberados**: `ferramentas/liberar_personagens.py` grava os códigos do CodeMasters Project direto no executável da ISO (`201E94B4 24020003` e `201E95AC 2402FFFF`). Ele confere os bytes antes e não altera nada se a versão do jogo for outra.
- **PCSX2 já configurado**: abre o jogo sozinho em tela cheia, sem o assistente inicial, com renderizador por CPU (VPS sem placa de vídeo) e controles do jogador 1 e 2 já mapeados.
- **HTTPS de verdade e senha** pelo Caddy, com endereço grátis `IP.sslip.io` (sem precisar comprar domínio).
- **Navegador protegido**: ninguém abre terminal, arquivos ou sudo pela página.

## Instalação (do seu Windows)

1. Crie a VPS com **Ubuntu 24.04** (veja a recomendação abaixo) e anote o **IP** e a **senha de root**.
2. Dê dois cliques em **`ENVIAR_PARA_VPS.bat`** e informe o IP.
   - Ele baixa este repositório na VPS, envia a BIOS e a ISO (2 GB, demora) e roda o instalador.
3. O instalador pergunta o **usuário** e a **senha do site**. No fim, mostra o link:
   `https://SEU-IP.sslip.io`

Para instalar manualmente na VPS:

```bash
git clone https://github.com/teodosioreal/NARUTINHO.git /opt/naruto5
# coloque a ISO em /opt/naruto5/jogo/ e a BIOS (.bin) em /opt/naruto5/bios/
sudo bash /opt/naruto5/instalar.sh
```

## Como jogar com um amigo

1. Abra o link, entre com usuário e senha e conecte seu controle (ou use o teclado).
2. No menu lateral da página, abra **Sharing** e copie o link de **Player 2**.
3. Mande o link para o amigo. Ele entra com a mesma senha, conecta o controle e aperta um botão. O controle dele vira o jogador 2.

O amigo precisa de um **controle** (USB ou Bluetooth, de Xbox ou PlayStation), porque o link de Player 2 só envia controle.

### Teclado do jogador 1

| PS2 | Tecla | PS2 | Tecla |
|---|---|---|---|
| Direcional | Setas ou WASD | Start | Enter |
| ✕ | K | Select | Backspace |
| ○ | L | L1 / R1 | Q / E |
| □ | J | L2 / R2 | 1 / 3 |
| △ | I | | |

## VPS recomendada

O PCSX2 depende muito do processador. O jogo e a codificação do vídeo rodam na CPU, então:

| | Recomendação |
|---|---|
| **Onde** | **São Paulo**, para ter pouco atraso no controle para quem está no Brasil |
| **CPU** | 4 vCPUs (de preferência dedicadas, AMD EPYC recente) |
| **RAM** | 8 GB |
| **Disco** | 40 GB+ |
| **Sistema** | Ubuntu 24.04 |

**Sugestão: [Vultr](https://www.vultr.com/pricing/), região São Paulo**, com cobrança por hora:
- Para testar: **High Performance, 4 vCPU / 8 GB**. É mais barato, mas a CPU é compartilhada.
- Se travar ou ficar lento: suba para **Optimized Cloud, CPU Optimized, 4 vCPU** (CPU dedicada).
- Como a cobrança é por hora, dá para criar, testar uma noite e apagar. São Paulo costuma ter um pequeno acréscimo no preço, então confira o valor no painel.

## Comandos úteis (na VPS)

```bash
cd /opt/naruto5
docker compose restart pcsx2   # reinicia o jogo
docker compose logs -f         # ver o que está acontecendo
docker compose down            # desligar
docker compose up -d           # ligar
rm .configurado && sudo bash instalar.sh   # trocar usuário/senha
```

Os saves (memory card) ficam em `config/.config/PCSX2/memcards/`.

## Problemas comuns

- **Jogo lento / som picotando**: a CPU da VPS está fraca. Use um plano com CPU dedicada.
- **Tela preta**: rode `docker compose logs pcsx2`. Se aparecer erro de *seccomp*, adicione `security_opt: [seccomp:unconfined]` ao serviço `pcsx2` no `docker-compose.yml`.
- **Erro de certificado ou site não abre**: confira se as portas 80 e 443 estão liberadas no firewall do painel da VPS.
- **Controle do amigo não funciona**: ele precisa abrir o link de *Player 2* (não o link normal) e apertar um botão do controle com a página em foco.
