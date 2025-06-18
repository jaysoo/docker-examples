const express = require('express');
const compression = require('compression');

const app = express();
app.use(compression());

app.get('/', (req, res) => {
  res.json({
    message: 'BuildKit cached app',
    buildkit: true,
    features: [
      'Cache mounts for npm',
      'Inline cache metadata',
      'Multi-stage optimization'
    ],
    timestamp: new Date().toISOString()
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`BuildKit demo server on port ${PORT}`);
});