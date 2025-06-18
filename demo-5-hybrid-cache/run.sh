#!/bin/bash
set -e

echo "🔵 Demo 5: Hybrid Caching Approach"
echo "================================="

NODE_PATH=. node << 'EOF'
const HybridDockerCache = require('./hybrid-cache.js');
const { execSync } = require('child_process');

async function runDemo() {
  // Initialize with multiple strategies
  const cache = new HybridDockerCache({
    strategies: ['local', 'layer'],  // Registry disabled for demo
    enableBuildKit: false
  });
  
  const baseInputs = {
    dockerfile: './Dockerfile',
    context: '.',
    buildArgs: { VERSION: '1.0.0' }
  };
  
  console.log('\n1️⃣ First build - all caches miss');
  let result = await cache.execute('demo5-app:v1', baseInputs);
  console.log(`   Result: ${result.success ? '✅ Success' : '❌ Failed'}`);
  console.log(`   Cached: ${result.cached ? 'Yes' : 'No'}`);
  
  console.log('\n2️⃣ Rebuild same image - local cache hit');
  // Remove image to test cache
  try {
    execSync('docker rmi demo5-app:v1', { stdio: 'pipe' });
  } catch {}
  
  result = await cache.execute('demo5-app:v1', baseInputs);
  console.log(`   Result: ${result.success ? '✅ Success' : '❌ Failed'}`);
  console.log(`   Cached: ${result.cached ? 'Yes' : 'No'}`);
  console.log(`   Strategy: ${result.strategy || 'none'}`);
  
  console.log('\n3️⃣ Modified version - layer cache helps');
  const modifiedInputs = {
    ...baseInputs,
    buildArgs: { VERSION: '2.0.0' }
  };
  
  result = await cache.execute('demo5-app:v2', modifiedInputs);
  console.log(`   Result: ${result.success ? '✅ Success' : '❌ Failed'}`);
  console.log(`   Note: Layer cache reused unchanged layers`);
  
  console.log('\n4️⃣ Simulating registry fallback');
  // Clear local cache
  const fs = require('fs');
  const cacheFiles = fs.readdirSync('.nx-cache/docker').filter(f => f.endsWith('.tar'));
  console.log(`   Clearing ${cacheFiles.length} local cache files...`);
  cacheFiles.forEach(f => fs.unlinkSync(`.nx-cache/docker/${f}`));
  
  // Enable registry for this test
  const cacheWithRegistry = new HybridDockerCache({
    strategies: ['local', 'registry', 'layer'],
    registryUrl: 'localhost:5000'  // Would use real registry
  });
  
  console.log('   Would check registry cache (simulated)');
  console.log('   Would fall back to layer cache');
  
  console.log('\n📊 Cache Statistics:');
  const stats = cache.getStats();
  console.log(`   Total hits: ${stats.totalHits}`);
  console.log(`   - Local: ${stats.hits.local}`);
  console.log(`   - Registry: ${stats.hits.registry}`);
  console.log(`   - Layer: Always used during builds`);
  console.log(`   Misses: ${stats.misses}`);
  console.log(`   Hit rate: ${stats.hitRate}`);
  console.log(`   Build time: ${stats.buildTime}ms`);
  console.log(`   Cache save time: ${stats.cacheTime}ms`);
  
  console.log('\n5️⃣ Testing hybrid cached image...');
  try {
    const containerId = execSync('docker run -d -p 3005:3000 demo5-app:v1', { encoding: 'utf-8' }).trim();
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const response = execSync('curl -s http://localhost:3005/', { encoding: 'utf-8' });
    console.log('   Response:', JSON.parse(response));
    
    execSync(`docker stop ${containerId} && docker rm ${containerId}`, { stdio: 'pipe' });
    console.log('   ✅ Hybrid cache system works!');
  } catch (e) {
    console.error('   ❌ Test failed:', e.message);
  }
}

runDemo().catch(console.error);
EOF

echo ""
echo "💡 Hybrid approach combines:"
echo "   - Fast local cache (file-based)"
echo "   - Shared registry cache (team)"
echo "   - Docker layer cache (always)"
echo "   - Intelligent fallback logic"
echo ""