FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gdal-bin \
    libgdal-dev \
    python3-dev \
    python3-pip \
    curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal

RUN pip install --upgrade pip && pip install numpy

RUN GDAL_VERSION=$(gdal-config --version) && \
    pip install gdal=="$GDAL_VERSION"

# 👇 COPY the script before chmod
COPY django.sh /app/django.sh
RUN chmod +x /app/django.sh

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

ENTRYPOINT ["/app/django.sh"]
