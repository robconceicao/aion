FROM python:3.11-slim

WORKDIR /app

# Instala ferramentas de sistema necessárias
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install gunicorn uvicorn

COPY . .

# Expõe a porta dinâmica (padrão 8000 se não definido)
EXPOSE 8000

# O comando será sobrescrito pelo Procfile ou pelo painel do servidor
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
