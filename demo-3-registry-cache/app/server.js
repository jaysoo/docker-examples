const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    message: 'Registry-cached Docker app',
    registry: process.env.REGISTRY_URL || 'unknown',
    cacheTag: process.env.CACHE_TAG || 'unknown',
    timestamp: new Date().toISOString()
  }, null, 2));
});

server.listen(3000, () => {
  console.log('Server running on port 3000');
});