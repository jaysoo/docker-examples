const express = require('express');
require('dotenv').config();

const app = express();

app.get('/', (req, res) => {
  res.json({
    message: 'Hybrid cache demo app',
    cacheStrategy: process.env.CACHE_STRATEGY || 'unknown',
    version: process.env.VERSION || '1.0.0',
    features: [
      'Local file cache',
      'Registry cache',
      'Layer cache',
      'Intelligent fallback'
    ]
  });
});

app.get('/stats', (req, res) => {
  res.json({
    cache: {
      local: process.env.LOCAL_CACHE_HITS || 0,
      registry: process.env.REGISTRY_CACHE_HITS || 0,
      layer: process.env.LAYER_CACHE_HITS || 0
    }
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Hybrid cache demo on port ${PORT}`);
});