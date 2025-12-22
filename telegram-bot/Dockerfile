FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN pip install --no-cache-dir python-telegram-bot==21.6 requests==2.32.3

COPY bot.py /app/bot.py

CMD ["python", "-m", "bot"]

