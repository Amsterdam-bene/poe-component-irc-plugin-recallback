#!/usr/bin/python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

def get_data(req):
    l = int(req.headers.get("Content-Length"))
    buf = req.rfile.read(l)
    j = json.loads(buf)
    return j

class Microservice(BaseHTTPRequestHandler):
    def do_POST(self):
        service_reply = '{"reply":"'
        j = get_data(self)
        original_text=j["text"]
        nick=j["nick"]
        service_reply += 'Hello there, %s"}' % nick
        self.send_response(200)
        self.send_header("Content-Type","application/json")
        self.end_headers()
        self.wfile.write(bytes(service_reply, 'utf-8'))

hs = HTTPServer(('',8001), Microservice)
hs.serve_forever()

