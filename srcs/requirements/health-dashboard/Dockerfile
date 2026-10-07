FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY app/server.py /app/server.py

CMD ["python3", "/app/server.py"]
