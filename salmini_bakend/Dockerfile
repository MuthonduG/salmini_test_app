FROM python:3.11-slim

WORKDIR /app

# System dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gdal-bin \
    libgdal-dev \
    python3-dev \
    python3-pip \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set GDAL include paths
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV C_INCLUDE_PATH=/usr/include/gdal

# Install numpy first
RUN pip install --upgrade pip && pip install numpy

# Get GDAL version dynamically and install
RUN GDAL_VERSION=$(gdal-config --version) && \
    pip install gdal=="$GDAL_VERSION"

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

ENTRYPOINT [ "/app/django.sh" ]