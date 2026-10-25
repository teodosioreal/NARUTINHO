"""Chat de voz do Naruto 5 Online: so apresenta as pessoas de cada sala.

O audio vai direto entre os navegadores (WebRTC); este servidor so repassa
as mensagens de conexao (oferta, resposta, candidatos ICE) e avisa quem
entrou, saiu ou se mutou.
"""
import asyncio
import itertools
import json

from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed

MAX_POR_SALA = 8
salas = {}  # nome da sala -> {id: {"ws", "nome", "mudo"}}
proximo_id = itertools.count(1)


async def enviar(ws, msg):
    try:
        await ws.send(json.dumps(msg))
    except Exception:
        pass


async def avisar_sala(sala, msg, exceto=None):
    for pid, p in list(salas.get(sala, {}).items()):
        if pid != exceto:
            await enviar(p["ws"], msg)


async def atendimento(ws):
    meu_id = str(next(proximo_id))
    sala = None
    try:
        async for bruto in ws:
            try:
                msg = json.loads(bruto)
            except ValueError:
                continue
            tipo = msg.get("tipo")

            if tipo == "entrar" and sala is None:
                nome_sala = str(msg.get("sala", ""))[:32]
                membros = salas.setdefault(nome_sala, {})
                if len(membros) >= MAX_POR_SALA:
                    await enviar(ws, {"tipo": "cheia"})
                    break
                sala = nome_sala
                nome = str(msg.get("nome", "")).strip()[:24] or f"Ninja {meu_id}"
                pessoas = [{"id": pid, "nome": p["nome"], "mudo": p["mudo"]} for pid, p in membros.items()]
                await enviar(ws, {"tipo": "bemvindo", "id": meu_id, "pessoas": pessoas})
                await avisar_sala(sala, {"tipo": "chegou", "id": meu_id, "nome": nome})
                membros[meu_id] = {"ws": ws, "nome": nome, "mudo": False}

            elif tipo == "sinal" and sala:
                alvo = salas.get(sala, {}).get(str(msg.get("para")))
                if alvo:
                    await enviar(alvo["ws"], {"tipo": "sinal", "de": meu_id, "dados": msg.get("dados")})

            elif tipo == "mudo" and sala:
                mudo = bool(msg.get("mudo"))
                salas[sala][meu_id]["mudo"] = mudo
                await avisar_sala(sala, {"tipo": "mudo", "id": meu_id, "mudo": mudo}, exceto=meu_id)
    except ConnectionClosed:
        pass  # fechou a aba sem se despedir
    finally:
        if sala and meu_id in salas.get(sala, {}):
            del salas[sala][meu_id]
            await avisar_sala(sala, {"tipo": "saiu", "id": meu_id})
            if not salas[sala]:
                del salas[sala]


async def main():
    async with serve(atendimento, "0.0.0.0", 8765, max_size=64 * 1024):
        print("Servidor de voz na porta 8765", flush=True)
        await asyncio.get_running_loop().create_future()


if __name__ == "__main__":
    asyncio.run(main())
