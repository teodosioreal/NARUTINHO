FROM python:3.12-slim
RUN pip install --no-cache-dir websockets==13.1
COPY servidor.py /app/servidor.py
CMD ["python", "-u", "/app/servidor.py"]
