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

# --- 3. Endereco, usuario e senha --------------------------------------------
IP=$(curl -fsS4 https://api.ipify.org || hostname -I | awk '{print $1}')
DOMINIO_PADRAO="${IP//./-}.sslip.io"
if [[ -f .configurado ]]; then
  source .configurado
else
  read -rp "Endereco do site [$DOMINIO_PADRAO]: " DOMINIO
  DOMINIO=${DOMINIO:-$DOMINIO_PADRAO}
  read -rp "Usuario para entrar no site [naruto]: " USUARIO
  USUARIO=${USUARIO:-naruto}
  while true; do
    read -rsp "Senha para entrar no site: " SENHA; echo
    [[ ${#SENHA} -ge 6 ]] && break
    echo "Use pelo menos 6 caracteres."
  done
  HASH=$(docker run --rm caddy:2 caddy hash-password --plaintext "$SENHA")
  printf 'DOMINIO=%q\nUSUARIO=%q\nHASH=%q\n' "$DOMINIO" "$USUARIO" "$HASH" > .configurado
  chmod 600 .configurado
fi

cat > Caddyfile <<EOF
$DOMINIO {
	basic_auth {
		$USUARIO $HASH
	}
	reverse_proxy pcsx2:3000
}
EOF

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
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow 80/tcp && ufw allow 443/tcp
fi

msg "Subindo o servidor (a primeira vez demora alguns minutos)..."
docker compose pull
docker compose up -d --force-recreate

echo
echo "=============================================================="
echo "  PRONTO! Abra no navegador:  https://$DOMINIO"
echo "  Usuario: $USUARIO   (senha: a que voce escolheu)"
echo
echo "  Amigo como jogador 2: menu lateral > Sharing > copie o link"
echo "  de 'Player 2' e mande para ele (ele usa a mesma senha)."
echo "=============================================================="
