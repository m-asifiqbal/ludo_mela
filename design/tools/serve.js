// Tiny static server for the design artboards (no dependencies).
//   node design/tools/serve.js            → http://127.0.0.1:5179/preview.html?f=Main.dc.html&still=1
// preview.html is a stand-in for the DC runtime ({{holes}}, sc-for, sc-if, on* handlers, setState).
// Use design/tools/shot.sh <Board.dc.html> [w h] to screenshot a board with headless Chrome.
const http = require('http');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..', 'artboards');
const port = Number(process.argv[2] || 5179);
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.css': 'text/css' };
http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  const file = path.join(root, url === '/' ? 'preview.html' : url);
  if (!file.startsWith(root)) { res.writeHead(403); return res.end(); }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); return res.end('not found'); }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(data);
  });
}).listen(port, '127.0.0.1', () => console.log('artboards on http://127.0.0.1:' + port));
