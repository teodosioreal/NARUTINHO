#!/bin/bash
# Instala o Naruto 5 Online numa VPS Ubuntu: uma pagina de entrada + varias salas,
# cada sala com o seu proprio PCSX2 (jogador 1, jogador 2 e quem quiser assistir).
# Uso: sudo bash instalar.sh
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
PASTA="$(pwd)"

msg() { echo -e "\n\033[1;33m==> $*\033[0m"; }
erro() { echo -e "\n\033[1;31mERRO: $*\033[0m"; exit 1; }

[[ $EUID -eq 0 ]] || erro "rode como root: sudo bash instalar.sh"

# --- 1. Docker ---------------------------------------------------------------
if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
  msg "Instalando Docker..."
  curl -fsSL https://get.docker.com | sh
fi

# --- 2. Jogo -----------------------------------------------------------------
mkdir -p jogo bios
if [[ ! -f jogo/naruto5.iso ]]; then
  ISO=$(find jogo -maxdepth 1 -iname '*.iso' | head -n1)
  [[ -n "$ISO" ]] || erro "coloque a ISO do jogo na pasta $PASTA/jogo"
  mv "$ISO" jogo/naruto5.iso
fi
msg "Liberando todos os personagens..."
python3 ferramentas/liberar_personagens.py jogo/naruto5.iso

BIOS=$(find bios -maxdepth 1 -iname '*.bin' | head -n1)
[[ -n "$BIOS" ]] || erro "coloque a BIOS do PS2 (.bin) na pasta $PASTA/bios"
BIOS_NOME=$(basename "$BIOS")

# --- 3. Modo, endereco, usuario e senha --------------------------------------
porta_ocupada() { ss -tlnH "sport = :$1" | grep -q .; }

IP=$(curl -fsS4 https://api.ipify.org || hostname -I | awk '{print $1}')
NUCLEOS=$(nproc)
if [[ -f .configurado ]]; then
  source .configurado
else
  # Se ja existe outro site (nginx, apache...) nas portas 80/443, nao mexe nele:
  # usa o modo teste, com portas proprias e certificado do proprio Caddy.
  if porta_ocupada 80 || porta_ocupada 443; then
    MODO=teste
    echo "As portas 80/443 ja estao em uso por outro programa (seu site continua intacto)."
    PORTA=8443
    while porta_ocupada "$PORTA"; do PORTA=$((PORTA + 1)); done
    echo "Usando o modo teste a partir da porta $PORTA."
    DOMINIO=""
  else
    MODO=normal
    PORTA=443
    DOMINIO_PADRAO="${IP//./-}.sslip.io"
    read -rp "Endereco do site [$DOMINIO_PADRAO]: " DOMINIO
    DOMINIO=${DOMINIO:-$DOMINIO_PADRAO}
  fi
  read -rp "Usuario para entrar no site [naruto]: " USUARIO
  USUARIO=${USUARIO:-naruto}
  while true; do
    read -rsp "Senha para entrar no site: " SENHA; echo
    [[ ${#SENHA} -ge 6 ]] && break
    echo "Use pelo menos 6 caracteres."
  done
  HASH=$(docker run --rm caddy:2 caddy hash-password --plaintext "$SENHA")
  SALAS=$(( NUCLEOS / 4 )); (( SALAS < 1 )) && SALAS=1
  printf 'MODO=%q\nDOMINIO=%q\nPORTA=%q\nUSUARIO=%q\nHASH=%q\nSALAS=%q\n' \
    "$MODO" "$DOMINIO" "$PORTA" "$USUARIO" "$HASH" "$SALAS" > .configurado
  chmod 600 .configurado
fi

# Cada sala e um PS2 inteiro rodando: ~4 nucleos e ~2 GB de RAM por sala
SUGESTAO=$(( NUCLEOS / 4 )); (( SUGESTAO < 1 )) && SUGESTAO=1
echo
echo "Esta VPS tem $NUCLEOS nucleos: aguenta bem cerca de $SUGESTAO sala(s)."
read -rp "Quantas salas criar? [$SALAS]: " RESP
SALAS=${RESP:-$SALAS}
[[ $SALAS =~ ^[1-9][0-9]?$ ]] || erro "numero de salas invalido: $SALAS"
sed -i "s/^SALAS=.*/SALAS=$SALAS/" .configurado

# Senha do TURN (retransmissor da voz para quem esta atras de CGNAT)
if [[ -z ${TURN_SENHA:-} ]]; then
  TURN_SENHA=$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')
  echo "TURN_SENHA=$TURN_SENHA" >> .configurado
fi

# Endereco de cada coisa
if [[ $MODO == normal ]]; then
  ENDERECO_ENTRADA="$DOMINIO"
  endereco_sala() { echo "sala$1.$DOMINIO"; }
  TLS=""
else
  ENDERECO_ENTRADA="$IP:$PORTA"
  endereco_sala() { echo "$IP:$((PORTA + $1))"; }
  TLS="	tls internal"
fi

# --- 4. Caddy (HTTPS + senha), pagina de entrada e docker-compose ------------
msg "Gerando as $SALAS sala(s)..."
AUTH="	basic_auth {
		$USUARIO $HASH
	}"

{
  echo "{"
  echo "	auto_https disable_redirects"
  echo "}"
  echo
  echo "https://$ENDERECO_ENTRADA {"
  echo "$AUTH"
  [[ -n $TLS ]] && echo "$TLS"
  echo "	handle /voz/ws {"
  echo "		reverse_proxy voz:8765"
  echo "	}"
  echo "	handle {"
  echo "		root * /srv/entrada"
  echo "		file_server"
  echo "	}"
  echo "}"
  for i in $(seq 1 "$SALAS"); do
    echo
    echo "https://$(endereco_sala "$i") {"
    echo "$AUTH"
    [[ -n $TLS ]] && echo "$TLS"
    echo "	reverse_proxy sala$i:3000"
    echo "}"
  done
} > Caddyfile

mkdir -p entrada
cp pagina/index.html entrada/index.html
{
  echo "window.SALAS = ["
  for i in $(seq 1 "$SALAS"); do
    echo "  { nome: 'Sala $i', url: 'https://$(endereco_sala "$i")/' },"
  done
  echo "];"
  echo "window.VOZ_ICE = ["
  echo "  { urls: 'stun:$IP:3478' },"
  echo "  { urls: ['turn:$IP:3478?transport=udp', 'turn:$IP:3478?transport=tcp'], username: 'naruto', credential: '$TURN_SENHA' },"
  echo "];"
} > entrada/salas.js

if [[ $MODO == normal ]]; then
  PORTAS_HOST="80 443"
  PORTAS_COMPOSE='      - "80:80"
      - "443:443"'
else
  PORTAS_HOST=$(seq "$PORTA" $((PORTA + SALAS)) | tr '\n' ' ')
  PORTAS_COMPOSE="      - \"$PORTA-$((PORTA + SALAS)):$PORTA-$((PORTA + SALAS))\""
fi

{
  cat <<EOF
# Gerado pelo instalar.sh: para mudar, rode o instalador de novo.
x-sala: &sala
  image: lscr.io/linuxserver/pcsx2:latest
  shm_size: "1gb"
  restart: unless-stopped
  networks: [interna]

x-ambiente: &ambiente
  PUID: "1000"
  PGID: "1000"
  TZ: America/Sao_Paulo
  # Resolucao fixa: menos trabalho para a VPS e mesma imagem para todos
  SELKIES_MANUAL_WIDTH: "1280"
  SELKIES_MANUAL_HEIGHT: "720"
  SELKIES_FRAMERATE: "60"
  # Link de jogador 2 (o controle do amigo cai so no slot 2)
  SELKIES_ENABLE_SHARING: "true"
  SELKIES_ENABLE_PLAYER2: "true"
  SELKIES_ENABLE_PLAYER3: "false"
  SELKIES_ENABLE_PLAYER4: "false"
  # Ninguem consegue abrir terminal, arquivos ou sudo pelo navegador
  HARDEN_DESKTOP: "true"
  # Se o PCSX2 fechar, ele abre o jogo de novo sozinho
  RESTART_APP: "true"

services:
  caddy:
    image: caddy:2
    container_name: naruto5-caddy
    ports:
$PORTAS_COMPOSE
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./entrada:/srv/entrada:ro
      - ./caddy/data:/data
      - ./caddy/config:/config
    restart: unless-stopped
    networks: [interna]

  # Chat de voz: apresenta as pessoas de cada sala (o audio vai direto entre elas)
  voz:
    build: ./voz
    container_name: naruto5-voz
    restart: unless-stopped
    networks: [interna]

  # Retransmite a voz quando a conexao direta nao passa (CGNAT, 4G...)
  turn:
    image: coturn/coturn:4.6
    container_name: naruto5-turn
    network_mode: host
    restart: unless-stopped
    command:
      - -n
      - --listening-port=3478
      - --min-port=49160
      - --max-port=49200
      - --external-ip=$IP
      - --realm=naruto5
      - --lt-cred-mech
      - --user=naruto:$TURN_SENHA
      - --fingerprint
      - --no-tls
      - --no-dtls
      - --no-cli
      - --no-multicast-peers
      - --denied-peer-ip=10.0.0.0-10.255.255.255
      - --denied-peer-ip=172.16.0.0-172.31.255.255
      - --denied-peer-ip=192.168.0.0-192.168.255.255
      - --log-file=stdout
EOF
  for i in $(seq 1 "$SALAS"); do
    cat <<EOF

  sala$i:
    <<: *sala
    container_name: naruto5-sala$i
    environment:
      <<: *ambiente
      SELKIES_UI_TITLE: "Naruto 5 - Sala $i"
    volumes:
      - ./config/sala$i:/config
      - ./jogo:/jogo:ro
EOF
  done
  cat <<EOF

networks:
  interna:
EOF
} > docker-compose.yml

# --- 5. PCSX2 ja configurado em cada sala ------------------------------------
msg "Configurando o PCSX2..."
THREADS=$(( NUCLEOS / SALAS - 2 )); (( THREADS < 1 )) && THREADS=1; (( THREADS > 8 )) && THREADS=8
for i in $(seq 1 "$SALAS"); do
  C=config/sala$i
  CFG=$C/.config/PCSX2
  mkdir -p "$CFG/inis" "$CFG/bios" "$C/.config/labwc" "$C/.config/openbox"
  cp "$BIOS" "$CFG/bios/"
  sed -e "s|__BIOS__|$BIOS_NOME|" -e "s|__THREADS__|$THREADS|" pcsx2/PCSX2.ini > "$CFG/inis/PCSX2.ini"
  # Save completo no memory card, so na primeira vez (nao apaga o progresso da sala)
  if [[ -f save/Mcd001.ps2 && ! -f $CFG/memcards/Mcd001.ps2 ]]; then
    mkdir -p "$CFG/memcards"
    cp save/Mcd001.ps2 "$CFG/memcards/Mcd001.ps2"
  fi
  for wm in labwc openbox; do
    cp pcsx2/autostart "$C/.config/$wm/autostart"
    chmod +x "$C/.config/$wm/autostart"
  done
done
chown -R 1000:1000 config

# --- 6. Firewall e subir -----------------------------------------------------
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  for p in $PORTAS_HOST; do ufw allow "$p/tcp"; done
  ufw allow 3478 && ufw allow 49160:49200/udp
fi

msg "Subindo o servidor (a primeira vez demora alguns minutos)..."
docker compose pull --ignore-buildable
docker compose up -d --build --force-recreate --remove-orphans

echo
echo "=============================================================="
echo "  PRONTO! Pagina de entrada:  https://$ENDERECO_ENTRADA"
echo "  Usuario: $USUARIO   (senha: a que voce escolheu)"
echo
for i in $(seq 1 "$SALAS"); do
  echo "  Sala $i:  https://$(endereco_sala "$i")"
done
if [[ $MODO == teste ]]; then
  echo
  echo "  MODO TESTE: o navegador vai avisar que o site 'nao e seguro'"
  echo "  (certificado proprio). Clique em Avancado > Continuar, em cada sala."
  echo "  Libere as portas $PORTAS_HOST no firewall do painel da VPS, se houver."
fi
echo
echo "  Chat de voz: no firewall do painel da VPS, libere tambem"
echo "  3478 (TCP e UDP) e 49160-49200 (UDP)."
echo "=============================================================="
