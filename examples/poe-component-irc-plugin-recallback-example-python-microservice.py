#!/usr/bin/python3

'''
Example POE::Component::IRC::Plugin::ReCallback handler.
Enable this by writing in ./callbacks.pl:

    [
      {
          trigger => qr/^yolo\b/i,
          url => 'http://localhost:9999/yolo',
      },
    ];

Launch this and run in another shell:
$ curl \
    -XPOST \
    --header 'Content-Type: application/json' \
    --data '{"channel":"##dipreathon","my_own_nick":"HeliumMuskBot","nick":"jojo","sender":"jojo!~jojo@wherever","text":"yolo anywhere!"}' \
    http://localhost:9999/yolo
'''

from http.server import HTTPServer, BaseHTTPRequestHandler
import json

def get_data(req):
    content_length = int(req.headers.get("Content-Length"))
    buf = req.rfile.read(content_length)
    return json.loads(buf)

class Microservice(BaseHTTPRequestHandler):
    def do_POST(self):
        j = get_data(self)
        original_text=j["text"]
        nick=j["nick"]
        service_reply = {
            "reply": "yolo in bolo, %s" % nick,
        }
        response_body = bytes(
            json.dumps(service_reply, separators=(',',':')
        ), 'utf-8')

        self.send_response(200)
        self.send_header("Content-Type","application/json")
        self.end_headers()
        self.wfile.write(response_body)

hs = HTTPServer(('127.0.0.1', 9999), Microservice)
hs.serve_forever()

# vim: tabstop=4 shiftwidth=4 expandtab:
