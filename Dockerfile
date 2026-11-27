FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir telethon

COPY . /app

EXPOSE 8765

CMD ["python", "backend/telegram_bridge_server.py"]

