#!/bin/bash
set -e

echo "🔵 Demo 3: Registry-Based Caching"
echo "================================"

# Check if registry is running
if ! docker ps | grep -q "registry:2"; then
  echo ""
  echo "📦 Starting local Docker registry..."
  docker-compose up -d
  echo "   Waiting for registry to start..."
  sleep 5
else
  echo "✅ Registry already running"
fi

echo ""
echo "🔧 Running registry cache demo..."
echo ""

NODE_PATH=. node << 'EOF'
const RegistryCache = require('./registry-cache.js');
const { execSync } = require('child_process');

async function runDemo() {
  const cache = new RegistryCache('localhost:5000');
  const baseImage = 'demo3-app';
  
  // Test 1: First build (cache miss)
  console.log('1️⃣ First build (expecting cache miss)...');
  
  const inputs1 = {
    dockerfile: './Dockerfile',
    contextFiles: ['./app/server.js'],
    targetImage: 'demo3-app:v1',
    buildArgs: {
      REGISTRY_URL: 'localhost:5000'
    }
  };
  
  const result1 = await cache.checkCache(baseImage, inputs1);
  
  if (!result1.hit) {
    console.log('   Building image...');
    try {
      execSync(`docker build \
        -f ${inputs1.dockerfile} \
        -t ${inputs1.targetImage} \
        --build-arg CACHE_TAG=${result1.hash} \
        --build-arg REGISTRY_URL=${inputs1.buildArgs.REGISTRY_URL} \
        .`, { stdio: 'inherit' });
      
      console.log('   ✅ Build complete');
      
      // Push to registry cache
      await cache.pushToCache(inputs1.targetImage, result1.hash, baseImage);
    } catch (e) {
      console.error('   ❌ Build failed:', e.message);
      return;
    }
  }
  
  // Test 2: Remove local image and pull from cache
  console.log('\n2️⃣ Removing local image and pulling from cache...');
  
  try {
    execSync(`docker rmi ${inputs1.targetImage}`, { stdio: 'pipe' });
    execSync(`docker rmi ${result1.cacheTag}`, { stdio: 'pipe' });
    console.log('   Removed local images');
  } catch {}
  
  const result2 = await cache.checkCache(baseImage, inputs1);
  console.log(`   Result: ${result2.hit ? 'Successfully pulled from registry! ✅' : 'Failed ❌'}`);
  
  // Test 3: Simulate different machine/developer
  console.log('\n3️⃣ Simulating another developer (cache sharing)...');
  console.log('   Another developer with same code can pull from cache...');
  
  const inputs3 = {
    ...inputs1,
    targetImage: 'demo3-app:dev-copy'
  };
  
  const result3 = await cache.checkCache(baseImage, inputs3);
  if (result3.hit) {
    console.log('   ✅ Shared cache works! No build needed.');
  }
  
  // List cached images
  console.log('\n4️⃣ Listing cached images in registry...');
  await cache.listCachedImages(baseImage);
  
  // Test running
  console.log('\n5️⃣ Testing cached image...');
  try {
    const containerId = execSync('docker run -d -p 3003:3000 demo3-app:v1', { encoding: 'utf-8' }).trim();
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const response = execSync('curl -s http://localhost:3003/', { encoding: 'utf-8' });
    console.log('   Response:', JSON.parse(response));
    
    execSync(`docker stop ${containerId} && docker rm ${containerId}`, { stdio: 'pipe' });
    console.log('   ✅ Registry-cached image works!');
  } catch (e) {
    console.error('   ❌ Test failed:', e.message);
  }
  
  // Show registry catalog
  console.log('\n📊 Registry catalog:');
  try {
    const catalog = execSync('curl -s http://localhost:5000/v2/_catalog', { encoding: 'utf-8' });
    console.log('   ', catalog.trim());
  } catch {}
}

runDemo().catch(console.error);
EOF

echo ""
echo "💡 Note: Registry remains running. Stop with: docker-compose down"
echo ""