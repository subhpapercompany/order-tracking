import http.server
import socketserver
import os
import json
import sys

DIRECTORY = os.path.dirname(os.path.abspath(__file__))
LOG_FILE = os.path.join(DIRECTORY, 'server.log')

# Safe Stream writer to prevent crashes when running under pythonw.exe (where stdout and stderr are None)
class SafeStream:
    def __init__(self, log_path=None):
        self.log_path = log_path

    def write(self, s):
        if not s:
            return
        if self.log_path:
            try:
                with open(self.log_path, 'a', encoding='utf-8') as f:
                    f.write(s)
            except Exception:
                pass

    def flush(self):
        pass

if sys.stdout is None:
    sys.stdout = SafeStream(LOG_FILE)
else:
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

if sys.stderr is None:
    sys.stderr = SafeStream(LOG_FILE)
else:
    try:
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

def log_msg(msg):
    try:
        if sys.stdout is not None:
            print(msg, flush=True)
    except Exception:
        pass

PORT = 8080
DB_FILE = os.path.join(DIRECTORY, 'data', 'Order_Tracking_Database.json')

def get_db_file_version():
    try:
        if os.path.exists(DB_FILE):
            return int(os.path.getmtime(DB_FILE) * 1000)
    except Exception:
        pass
    import time
    return int(time.time() * 1000)

CURRENT_DB_VERSION = get_db_file_version()

class SubhServerHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def log_message(self, format, *args):
        try:
            if sys.stderr is not None:
                sys.stderr.write("%s - - [%s] %s\n" %
                                 (self.address_string(),
                                  self.log_date_time_string(),
                                  format % args))
        except Exception:
            pass

    def end_headers(self):
        try:
            req_path = getattr(self, 'path', '') or ''
            clean_path = req_path.split('?')[0].lower()
            if clean_path.endswith('.json') or clean_path.endswith('.js') or clean_path.endswith('.html') or clean_path == '/' or clean_path == '' or clean_path.startswith('/api/'):
                self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
                self.send_header('Pragma', 'no-cache')
                self.send_header('Expires', '0')
        except Exception:
            pass
        super().end_headers()

    def do_GET(self):
        global CURRENT_DB_VERSION
        clean_path = self.path.split('?')[0]

        if clean_path == '/api/ping':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')
            return

        if clean_path == '/api/network-info':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            import socket
            local_ip = get_local_ip()
            tunnel_url = get_active_tunnel_url()
            resp_bytes = json.dumps({
                "status": "ok",
                "local_ip": local_ip,
                "port": PORT,
                "wifi_url": f"http://{local_ip}:{PORT}/",
                "hotspot_url": f"http://192.168.137.1:{PORT}/",
                "tunnel_url": tunnel_url,
                "hostname": socket.gethostname()
            }).encode('utf-8')
            self.wfile.write(resp_bytes)
            return

        if clean_path == '/api/version':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            resp = json.dumps({"status": "ok", "version": CURRENT_DB_VERSION}).encode('utf-8')
            self.wfile.write(resp)
            return

        if clean_path == '/api/load':
            try:
                if os.path.exists(DB_FILE):
                    with open(DB_FILE, 'rb') as f:
                        data = f.read()
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json; charset=utf-8')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    self.wfile.write(data)
                    return
                else:
                    self.send_response(404)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    self.wfile.write(b'{"status":"error","message":"No database file found on disk"}')
                    return
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps({"status":"error", "message":str(e)}).encode('utf-8'))
                return

        super().do_GET()

    def do_POST(self):
        global CURRENT_DB_VERSION
        clean_path = self.path.split('?')[0]

        if clean_path == '/api/save':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            try:
                payload = json.loads(post_data.decode('utf-8'))
                
                targets = [os.path.join(DIRECTORY, 'data')]
                f_drive_dir = r"F:\Order tracking HTML\data"
                if os.path.exists(r"F:\Order tracking HTML"):
                    targets.append(f_drive_dir)

                json_str = json.dumps(payload, indent=2, ensure_ascii=False)
                js_str = "/* SUBH PAPER COMPANY - AUTO-LOAD DATABASE COMPANION */\nwindow.ORDER_TRACKING_DATABASE = " + json_str + ";\n"

                for data_dir in targets:
                    try:
                        os.makedirs(data_dir, exist_ok=True)
                        json_path = os.path.join(data_dir, 'Order_Tracking_Database.json')
                        js_path = os.path.join(data_dir, 'Order_Tracking_Data.js')
                        with open(json_path, 'w', encoding='utf-8') as f:
                            f.write(json_str)
                        with open(js_path, 'w', encoding='utf-8') as f:
                            f.write(js_str)
                    except Exception as err:
                        log_msg(f"[SERVER WARN] Could not write to {data_dir}: {err}")

                import time
                CURRENT_DB_VERSION = int(time.time() * 1000)

                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                resp = json.dumps({"status":"success", "version": CURRENT_DB_VERSION, "message":"Database saved directly to server disk!"}).encode('utf-8')
                self.wfile.write(resp)
                log_msg(f"[SERVER] Live database updated on disk (Version: {CURRENT_DB_VERSION})")
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps({"status":"error", "message":str(e)}).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

def is_server_already_running(port):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(0.6)
            return s.connect_ex(('127.0.0.1', port)) == 0
    except Exception:
        return False

def get_local_ip():
    try:
        import socket
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        if ip and not ip.startswith('127.'):
            return ip
    except Exception:
        pass
    try:
        import socket
        hostname = socket.gethostname()
        ips = socket.gethostbyname_ex(hostname)[2]
        for ip in ips:
            if not ip.startswith('127.') and not ip.startswith('169.254.'):
                return ip
    except Exception:
        pass
    return '127.0.0.1'

def cloudflared_is_running():
    """cloudflared process actually chal raha hai ya nahi (stale URL guard)."""
    try:
        import subprocess
        out = subprocess.run(
            ['tasklist', '/FI', 'IMAGENAME eq cloudflared.exe'],
            capture_output=True, text=True, timeout=10
        ).stdout.lower()
        return 'cloudflared.exe' in out
    except Exception:
        return False


def get_active_tunnel_url():
    """Live tunnel URL return karta hai. Sirf tabhi jab cloudflared chal raha ho —
    warna purana (dead) URL QR me chhap jaata tha aur mobile scan karke fail hota tha."""
    import re
    if not cloudflared_is_running():
        return None

    # naye log pehle (cf.log) kyunki --logfile flag cloudflared me fail hota hai
    log_candidates = [
        os.path.join(DIRECTORY, 'data', 'cf.log'),
        os.path.join(DIRECTORY, 'cf.log'),
        os.path.join(DIRECTORY, 'data', 'cloudflared.log'),
        os.path.join(DIRECTORY, 'cloudflared.log')
    ]
    newest_url = None
    newest_mtime = -1
    for lp in log_candidates:
        if os.path.exists(lp):
            try:
                with open(lp, 'r', encoding='utf-8', errors='ignore') as f:
                    txt = f.read()
                m = re.findall(r'https://[a-zA-Z0-9-]+\.trycloudflare\.com', txt)
                if m:
                    mt = os.path.getmtime(lp)
                    if mt > newest_mtime:
                        newest_mtime = mt
                        newest_url = m[-1]
            except Exception:
                pass
    return newest_url

if __name__ == '__main__':
    if is_server_already_running(PORT):
        log_msg(f"[SERVER] Server is already actively responding on port {PORT}. Exiting duplicate launcher.")
        sys.exit(0)

    socketserver.ThreadingTCPServer.allow_reuse_address = True
    local_ip = get_local_ip()
    try:
        with socketserver.ThreadingTCPServer(("", PORT), SubhServerHandler) as httpd:
            log_msg("================================================================")
            log_msg("  SUBH PAPER COMPANY - LOCAL NETWORK WEB SERVER IS RUNNING!")
            log_msg(f"  Local Access:   http://localhost:{PORT}")
            log_msg(f"  Wi-Fi / LAN IP: http://{local_ip}:{PORT}")
            log_msg("================================================================")
            try:
                httpd.serve_forever()
            except KeyboardInterrupt:
                log_msg("\nServer stopped.")
    except Exception as e:
        log_msg(f"[SERVER ERROR] Could not start server: {e}")
