#!/bin/bash
# Comandos de administrador das salas.
#
#   sudo bash ferramentas/sala.sh inicio [N]     Salva o momento atual da sala N (padrao 1)
#                                                como estado inicial de TODAS as salas.
#                                                Deixe a sala na tela de selecao do versus antes.
#   sudo bash ferramentas/sala.sh reiniciar N    Volta a sala N para o estado inicial na hora
#                                                (ou reinicia o PCSX2 se nao houver estado).
#   sudo bash ferramentas/sala.sh tirar-inicio   Apaga o estado inicial (salas voltam a abrir do zero).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

pine() { docker exec -i "naruto5-sala$1" python3 - "$2" "$3" < ferramentas/pine.py; }
estados() { ls config/sala"$1"/.config/PCSX2/sstates/*.01.p2s 2>/dev/null; }
salas() { ls -d config/sala* | sed 's|config/sala||' | sort -n; }

case "${1:-}" in
  inicio)
    N=${2:-1}
    echo "Salvando o estado da sala $N..."
    rm -f config/sala"$N"/.config/PCSX2/sstates/*.01.p2s
    pine "$N" salvar 1
    for _ in $(seq 1 20); do estados "$N" >/dev/null && break; sleep 1; done
    sleep 2  # termina de gravar
    ORIGEM=$(estados "$N") || { echo "O estado nao apareceu. Tente de novo."; exit 1; }
    for i in $(salas); do
      [[ $i == "$N" ]] && continue
      D=config/sala$i/.config/PCSX2/sstates
      mkdir -p "$D" && rm -f "$D"/*.01.p2s
      cp "$ORIGEM" "$D/"
    done
    chown -R 1000:1000 config
    echo "Pronto: todas as salas vao comecar nesse ponto. Reiniciando as outras salas..."
    for i in $(salas); do [[ $i == "$N" ]] || docker restart "naruto5-sala$i" >/dev/null; done
    ;;
  reiniciar)
    N=${2:?informe a sala, ex: sala.sh reiniciar 2}
    if estados "$N" >/dev/null && pine "$N" carregar 1; then
      echo "Sala $N de volta ao inicio."
    else
      docker restart "naruto5-sala$N" >/dev/null && echo "Sala $N reiniciada."
    fi
    ;;
  tirar-inicio)
    rm -f config/sala*/.config/PCSX2/sstates/*.01.p2s
    echo "Estado inicial apagado. As salas abrem do zero na proxima vez que reiniciarem."
    ;;
  *)
    sed -n '2,10p' "$0"
    ;;
esac
