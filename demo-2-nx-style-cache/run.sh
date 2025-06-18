#!/bin/bash
set -e

echo "🔵 Demo 2: Nx-Style Hash-Based Caching"
echo "====================================="

# Load the cache module
NODE_PATH=. node << 'EOF'
const NxDockerCache = require('./nx-docker-cache.js');
const { execSync } = require('child_process');

async function runDemo() {
  const cache = new NxDockerCache();
  
  console.log('\n📊 Initial cache stats:');
  const stats = cache.getCacheStats();
  console.log(`   Entries: ${stats.entries}`);
  console.log(`   Total size: ${stats.totalSize}`);
  
  // Test 1: First build (cache miss)
  console.log('\n1️⃣ First build (expecting cache miss)...');
  const inputs1 = {
    dockerfile: './Dockerfile',
    context: './app',
    imageName: 'demo2-app:v1',
    buildArgs: { APP_VERSION: '1.0.0' }
  };
  
  const result1 = await cache.checkCache(inputs1);
  
  if (!result1.hit) {
    console.log('   Building image...');
    const startTime = Date.now();
    const buildTime = new Date().toISOString();
    
    try {
      execSync(`docker build \
        -f ${inputs1.dockerfile} \
        -t ${inputs1.imageName} \
        --build-arg APP_VERSION=${inputs1.buildArgs.APP_VERSION} \
        --build-arg BUILD_TIME="${buildTime}" \
        --build-arg CACHE_KEY=${result1.hash} \
        .`, { stdio: 'inherit' });
      
      const buildDuration = Date.now() - startTime;
      console.log(`   ✅ Built in ${buildDuration}ms`);
      
      // Save to cache
      await cache.saveToCache(result1.hash, inputs1.imageName, inputs1);
    } catch (e) {
      console.error('   ❌ Build failed:', e.message);
    }
  }
  
  // Test 2: Same build (cache hit)
  console.log('\n2️⃣ Rebuild with same inputs (expecting cache hit)...');
  
  // Remove the image first
  try {
    execSync(`docker rmi ${inputs1.imageName}`, { stdio: 'pipe' });
    console.log('   Removed existing image');
  } catch {}
  
  const result2 = await cache.checkCache(inputs1);
  console.log(`   Result: ${result2.hit ? 'Cache hit! ✅' : 'Cache miss ❌'}`);
  
  // Test 3: Different build args (cache miss)
  console.log('\n3️⃣ Build with different args (expecting cache miss)...');
  const inputs3 = {
    ...inputs1,
    imageName: 'demo2-app:v2',
    buildArgs: { APP_VERSION: '2.0.0' }
  };
  
  const result3 = await cache.checkCache(inputs3);
  
  if (!result3.hit) {
    console.log('   Building new version...');
    const buildTime = new Date().toISOString();
    
    try {
      execSync(`docker build \
        -f ${inputs3.dockerfile} \
        -t ${inputs3.imageName} \
        --build-arg APP_VERSION=${inputs3.buildArgs.APP_VERSION} \
        --build-arg BUILD_TIME="${buildTime}" \
        --build-arg CACHE_KEY=${result3.hash} \
        .`, { stdio: 'pipe' });
      
      console.log('   ✅ Built successfully');
      await cache.saveToCache(result3.hash, inputs3.imageName, inputs3);
    } catch (e) {
      console.error('   ❌ Build failed:', e.message);
    }
  }
  
  // Test 4: Modified source file
  console.log('\n4️⃣ Modifying source file...');
  const fs = require('fs');
  const serverPath = './app/server.js';
  const originalContent = fs.readFileSync(serverPath, 'utf-8');
  
  // Add a comment to change the hash
  fs.writeFileSync(serverPath, originalContent + '\n// Modified at ' + Date.now());
  console.log('   Modified server.js');
  
  const inputs4 = {
    ...inputs1,
    imageName: 'demo2-app:v3'
  };
  
  const result4 = await cache.checkCache(inputs4);
  console.log(`   Result: ${result4.hit ? 'Cache hit ✅' : 'Cache miss (expected) ✅'}`);
  
  // Restore original file
  fs.writeFileSync(serverPath, originalContent);
  
  // Final stats
  console.log('\n📊 Final cache stats:');
  const finalStats = cache.getCacheStats();
  console.log(`   Entries: ${finalStats.entries}`);
  console.log(`   Total size: ${finalStats.totalSize}`);
  
  // Test running a cached image
  console.log('\n5️⃣ Testing cached image...');
  try {
    const containerId = execSync('docker run -d -p 3002:3000 demo2-app:v1', { encoding: 'utf-8' }).trim();
    
    // Wait for startup
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const response = execSync('curl -s http://localhost:3002/', { encoding: 'utf-8' });
    console.log('   Response:', JSON.parse(response));
    
    // Cleanup
    execSync(`docker stop ${containerId} && docker rm ${containerId}`, { stdio: 'pipe' });
    console.log('   ✅ Cached image works correctly!');
  } catch (e) {
    console.error('   ❌ Test failed:', e.message);
  }
}

runDemo().catch(console.error);
EOF

echo ""
echo "📊 Cache contents:"
ls -la .nx-cache/docker/ 2>/dev/null || echo "   No cache directory yet"
echo ""