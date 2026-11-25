"""Optional unverified community leaderboard. Put behind HTTPS reverse proxy."""
import json, re, sqlite3, os, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
DB = os.environ.get("CLAY_DB", "clay_scores.sqlite3")
with sqlite3.connect(DB) as db:
    db.execute("CREATE TABLE IF NOT EXISTS scores (id TEXT PRIMARY KEY, score INTEGER NOT NULL, updated INTEGER NOT NULL)")
class Handler(BaseHTTPRequestHandler):
    def reply(self, code, value):
        data = json.dumps(value).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def top(self):
        with sqlite3.connect(DB) as db:
            rows = db.execute("SELECT id,score FROM scores ORDER BY score DESC,updated ASC LIMIT 10").fetchall()
        self.reply(200, [{"name":"Clay-"+i[:6], "score":s} for i,s in rows])
    def do_GET(self):
        if self.path != "/scores": return self.reply(404, {})
        self.top()
    def do_POST(self):
        if self.path != "/scores": return self.reply(404, {})
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 1024: raise ValueError()
            data = json.loads(self.rfile.read(size))
            player, score = data["id"], data["score"]
            if not isinstance(player, str) or not re.fullmatch(r"[a-f0-9]{32}",player): raise ValueError()
            if type(score) is not int or not 0 < score <= 1000000000: raise ValueError()
        except (ValueError, KeyError, TypeError):
            return self.reply(400,{})
        with sqlite3.connect(DB) as db:
            db.execute("INSERT INTO scores VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET score=MAX(score,excluded.score),updated=excluded.updated WHERE excluded.score>score AND excluded.updated-updated>=10",(player,score,int(time.time())))
        self.top()
if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("PORT","8080"))), Handler).serve_forever()
