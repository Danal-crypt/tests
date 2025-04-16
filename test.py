#!/usr/bin/env python3

import socket
import platform

# === CONFIG ===
hosts = ["host1.example.com", "host2.example.com"]  # Replace with actual hosts
port = 8089
protocol = "tcp"  # Change to "udp" if needed
timeout = 3
os_type = platform.system()

# === TEST LOGIC ===
for target in hosts:
    status = "No"
    conn_info = ""
    try:
        if protocol.lower() == "tcp":
            with socket.create_connection((target, port), timeout=timeout) as s:
                status = "Yes"
                local_addr = s.getsockname()
                remote_addr = s.getpeername()
                conn_info = f"local_addr={local_addr[0]}:{local_addr[1]} remote_addr={remote_addr[0]}:{remote_addr[1]}"
        elif protocol.lower() == "udp":
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.settimeout(timeout)
                s.sendto(b'test', (target, port))
                # No response expected; if no error on send, we assume success
                status = "Yes"
                conn_info = f"sent_udp_probe_to={target}:{port}"
        else:
            conn_info = "error=\"Unsupported protocol\""
    except Exception as e:
        conn_info = f"error=\"{str(e)}\""

    print(f"connect_test connected_host={target} port={port} protocol={protocol.upper()} connected={status} os={os_type} {conn_info}")
