#!/usr/bin/env python3

import socket
import http.client
from http.server import BaseHTTPRequestHandler, HTTPServer


SERVICES = [
    ("NGINX", "tcp", "nginx", 443),
    ("WordPress", "tcp", "wordpress", 9000),
    ("MariaDB", "tcp", "mariadb", 3306),
    ("Redis", "tcp", "redis", 6379),
    ("FTP", "tcp", "ftp", 21),
    ("Adminer", "http", "adminer", 8080),
    ("Static Site", "http", "static-site", 80),
]


def check_tcp(host, port, timeout=2):
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def check_http(host, port, timeout=2):
    try:
        connection = http.client.HTTPConnection(
            host,
            port,
            timeout=timeout,
        )

        connection.request("GET", "/")

        response = connection.getresponse()

        response.read()
        connection.close()

        return 200 <= response.status < 500

    except (OSError, http.client.HTTPException):
        return False


def check_service(protocol, host, port):
    if protocol == "tcp":
        return check_tcp(host, port)

    if protocol == "http":
        return check_http(host, port)

    return False


def build_page():
    rows = []

    for name, protocol, host, port in SERVICES:
        healthy = check_service(protocol, host, port)

        status = "UP" if healthy else "DOWN"
        css_class = "up" if healthy else "down"

        rows.append(
            f"""
            <div class="service">
                <div>
                    <strong>{name}</strong>
                    <span>{host}:{port}</span>
                </div>

                <span class="status {css_class}">
                    {status}
                </span>
            </div>
            """
        )

    services_html = "\n".join(rows)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta
        name="viewport"
        content="width=device-width, initial-scale=1.0"
    >

    <title>Inception Health</title>

    <style>
        * {{
            box-sizing: border-box;
        }}

        body {{
            margin: 0;
            min-height: 100vh;
            display: flex;
            justify-content: center;

            font-family: Arial, sans-serif;

            background: #111;
            color: #f5f5f5;
        }}

        main {{
            width: min(760px, 90%);
            padding: 60px 0;
        }}

        h1 {{
            margin-bottom: 10px;
            font-size: 2.5rem;
        }}

        .subtitle {{
            margin-bottom: 40px;
            color: #999;
        }}

        .service {{
            display: flex;
            align-items: center;
            justify-content: space-between;

            padding: 18px 0;

            border-bottom: 1px solid #333;
        }}

        .service div {{
            display: flex;
            flex-direction: column;
            gap: 5px;
        }}

        .service span {{
            color: #888;
            font-size: 0.85rem;
        }}

        .status {{
            padding: 6px 12px;

            border-radius: 20px;

            font-weight: bold;
        }}

        .status.up {{
            color: #6ee7a2;
            background: #153d27;
        }}

        .status.down {{
            color: #ff8585;
            background: #451d1d;
        }}
    </style>
</head>

<body>
    <main>
        <h1>Inception Health</h1>

        <p class="subtitle">
            Live availability checks through the Docker network.
        </p>

        {services_html}
    </main>
</body>
</html>
"""


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/":
            self.send_error(404)
            return

        body = build_page().encode("utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()

        self.wfile.write(body)

    def log_message(self, format, *args):
        print(
            f"{self.client_address[0]} - "
            f"{format % args}"
        )


def main():
    server = HTTPServer(
        ("0.0.0.0", 9001),
        HealthHandler,
    )

    print("Health dashboard listening on port 9001")

    server.serve_forever()


if __name__ == "__main__":
    main()
