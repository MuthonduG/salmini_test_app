#!/bin/bash
set -e

echo "Waiting for DB to be ready..."
until nc -z $DB_HOST $DB_PORT; do
  echo "Waiting for database at $DB_HOST:$DB_PORT..."
  sleep 2
done

echo "Running migrations"
python manage.py makemigrations
python manage.py migrate

echo "Starting Django server"
python manage.py runserver 0.0.0.0:8000
