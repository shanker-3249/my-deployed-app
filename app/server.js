const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }

  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>My Deployed App</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', sans-serif;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
    }
    .card {
      background: rgba(255,255,255,0.08);
      border: 1px solid rgba(255,255,255,0.15);
      border-radius: 16px;
      padding: 48px 56px;
      text-align: center;
      max-width: 520px;
      backdrop-filter: blur(10px);
    }
    .badge {
      background: #00d4aa;
      color: #0f3460;
      font-size: 12px;
      font-weight: 700;
      padding: 4px 14px;
      border-radius: 20px;
      display: inline-block;
      margin-bottom: 20px;
      letter-spacing: 1px;
      text-transform: uppercase;
    }
    h1 { font-size: 2.2rem; margin-bottom: 12px; }
    p { color: rgba(255,255,255,0.65); margin-bottom: 8px; font-size: 0.95rem; }
    .meta { margin-top: 28px; padding-top: 24px; border-top: 1px solid rgba(255,255,255,0.1); }
    .meta p { font-size: 0.85rem; }
    .highlight { color: #00d4aa; font-weight: 600; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">✅ Live</div>
    <h1>Hello from AWS! 🚀</h1>
    <p>Your Node.js app is successfully deployed on EC2.</p>
    <div class="meta">
      <p>Host: <span class="highlight">${os.hostname()}</span></p>
      <p>Time: <span class="highlight">${new Date().toUTCString()}</span></p>
      <p>Node: <span class="highlight">${process.version}</span></p>
    </div>
  </div>
</body>
</html>`;

  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(html);
});

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
