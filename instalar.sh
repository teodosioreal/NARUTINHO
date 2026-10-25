#!/bin/bash
# Instala o Naruto 5 Online numa VPS Ubuntu (22.04 ou 24.04).
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
if [[ -f .configurado ]]; then
  source .configurado
else
  # Se ja existe outro site (nginx, apache...) nas portas 80/443, nao mexe nele:
  # usa o modo teste, numa porta propria com o HTTPS do proprio container.
  if porta_ocupada 80 || porta_ocupada 443; then
    MODO=teste
    echo "As portas 80/443 ja estao em uso por outro programa (seu site continua intacto)."
    PORTA=8443
    while porta_ocupada "$PORTA"; do PORTA=$((PORTA + 1)); done
    echo "Usando o modo teste na porta $PORTA."
  else
    MODO=normal
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
  if [[ $MODO == normal ]]; then
    HASH=$(docker run --rm caddy:2 caddy hash-password --plaintext "$SENHA")
    printf 'MODO=normal\nDOMINIO=%q\nUSUARIO=%q\nHASH=%q\n' "$DOMINIO" "$USUARIO" "$HASH" > .configurado
  else
    printf 'MODO=teste\nPORTA=%q\nUSUARIO=%q\nSENHA=%q\n' "$PORTA" "$USUARIO" "$SENHA" > .configurado
  fi
  chmod 600 .configurado
fi

if [[ $MODO == normal ]]; then
  rm -f docker-compose.override.yml
  cat > Caddyfile <<EOF
$DOMINIO {
	basic_auth {
		$USUARIO $HASH
	}
	reverse_proxy pcsx2:3000
}
EOF
else
  # Senha e HTTPS (certificado autoassinado) feitos pelo proprio container
  cat > docker-compose.override.yml <<EOF
services:
  pcsx2:
    ports:
      - "$PORTA:3001"
    environment:
      - CUSTOM_USER=$USUARIO
      - PASSWORD=$SENHA
EOF
  chmod 600 docker-compose.override.yml
fi

# --- 4. PCSX2 ja configurado -------------------------------------------------
msg "Configurando o PCSX2..."
CFG=config/.config/PCSX2
mkdir -p "$CFG/inis" "$CFG/bios" config/.config/labwc config/.config/openbox
cp "$BIOS" "$CFG/bios/"
THREADS=$(( $(nproc) - 2 )); (( THREADS < 1 )) && THREADS=1; (( THREADS > 8 )) && THREADS=8
sed -e "s|__BIOS__|$BIOS_NOME|" -e "s|__THREADS__|$THREADS|" pcsx2/PCSX2.ini > "$CFG/inis/PCSX2.ini"
cp pcsx2/autostart config/.config/labwc/autostart
cp pcsx2/autostart config/.config/openbox/autostart
chmod +x config/.config/labwc/autostart config/.config/openbox/autostart
chown -R 1000:1000 config

# --- 5. Firewall e subir -----------------------------------------------------
if [[ $MODO == normal ]]; then PORTAS="80 443"; else PORTAS="$PORTA"; fi
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  for p in $PORTAS; do ufw allow "$p/tcp"; done
fi

msg "Subindo o servidor (a primeira vez demora alguns minutos)..."
if [[ $MODO == normal ]]; then
  docker compose pull
  docker compose up -d --force-recreate
  LINK="https://$DOMINIO"
else
  docker compose rm -sf caddy >/dev/null 2>&1 || true
  docker compose pull pcsx2
  docker compose up -d --force-recreate pcsx2
  LINK="https://$IP:$PORTA"
fi

echo
echo "=============================================================="
echo "  PRONTO! Abra no navegador:  $LINK"
echo "  Usuario: $USUARIO   (senha: a que voce escolheu)"
if [[ $MODO == teste ]]; then
  echo
  echo "  MODO TESTE: o navegador vai avisar que o site 'nao e seguro'"
  echo "  (certificado proprio). Clique em Avancado > Continuar."
  echo "  Libere a porta $PORTA no firewall do painel da VPS, se houver."
fi
echo
echo "  Amigo como jogador 2: menu lateral > Sharing > copie o link"
echo "  de 'Player 2' e mande para ele (ele usa a mesma senha)."
echo "=============================================================="
