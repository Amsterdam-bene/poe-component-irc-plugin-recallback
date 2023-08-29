#!/usr/bin/env python3

import requests

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import re
import random
from datetime import datetime

tenor_api_key = 'LOL'
locale = 'it_IT'

def log(message):
    print(f'{datetime.now()} {message}')

def get_data(req):
    content_length = int(req.headers.get("Content-Length"))
    buf = req.rfile.read(content_length)
    return json.loads(buf)

def get_lookup_key(original_text):
    # This used to be just...:
    #     lookup_key = re.sub(r'\.(jpe?g|gif|png)$', '', original_text)
    #     lookup_key = re.sub(r'[-_]+', ' ', lookup_key)
    # ... but that also triggers for e.g. imgur urls and doesn't play well with
    # texts that have non-lookup words mixed with lookups

    # Strip existing URLs.  If https://some/url.jpg is the only thing that
    # made this trigger, it's not actually meant to trigger
    lookup_key = re.sub(r'https?://\S+', '', original_text)
    if not re.search(r'(?i).(jpe?g|gifv?|png|bmp|tiff?|svg)', lookup_key):
        return None

    lookup_key = re.sub(r'(?i).*?(\S+)\.(jpe?g|gif|png|bmp|tiff?|svg).*', '\\1', lookup_key)
    lookup_key = re.sub(r'[-_\s]+', ' ', lookup_key)
    lookup_key = re.sub(r'\s+$', '', lookup_key)
    lookup_key = re.sub(r'^\s+', '', lookup_key)

    return lookup_key

class Microservice(BaseHTTPRequestHandler):
    def do_POST(self):
        j = get_data(self)
        original_text = j["text"]
        nick = j["nick"]

        lookup_key = get_lookup_key(original_text)
        log(f'Lookup key <{lookup_key}>')
        if not lookup_key:
            self.send_response(200)
            self.send_header("Content-Type","application/json")
            self.end_headers()
            self.wfile.write(b'{}')
            return

        response = requests.get(f'https://g.tenor.com/v1/random?key={tenor_api_key}&locale={locale}&q={lookup_key}', timeout=3.0)

        reply = random.choice([ result['media'][0]['gif']['url'] for result in response.json()['results'] ])

        lookup_key_sanitized = re.sub(r'[^a-z0-9]+', '-', lookup_key)
        log(f'Reply <{reply}>')
        log(f'Sanitized  <{lookup_key_sanitized}>')
        reply = re.sub(r'/tenor\.gif$', f'/{lookup_key_sanitized}.gif', reply)
        log(f'Reply -> Sanitized <{reply}>')

        service_reply = {
            "reply": reply,
        }
        response_body = bytes(
            json.dumps(service_reply, separators=(',',':')
        ), 'utf-8')

        self.send_response(200)
        self.send_header("Content-Type","application/json")
        self.end_headers()
        self.wfile.write(response_body)

hs = HTTPServer(('127.0.0.1', 9994), Microservice)
hs.serve_forever()

# vim: tabstop=4 shiftwidth=4 expandtab:
