FROM python:3.13y-slim

ENV PYTHONBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1

WORKDIR /app

COPY requirements.txt .
COPY .env .

RUN pip install --no-cache-dir -r requirements.txt

COPY django.sh /app/django.sh
RUN chmod +x /app/django.sh

COPY . .

EXPOSE 8000

ENTRYPOINT [ "/app/django.sh" ]