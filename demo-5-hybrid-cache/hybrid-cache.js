#!/usr/bin/env node
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class HybridDockerCache {
  constructor(options = {}) {
    this.localCacheDir = options.localCacheDir || '.nx-cache/docker';
    this.registryUrl = options.registryUrl || null;
    this.enableBuildKit = options.enableBuildKit || false;
    this.strategies = options.strategies || ['local', 'registry', 'layer'];
    
    this.stats = {
      hits: { local: 0, registry: 0, layer: 0 },
      misses: 0,
      buildTime: 0,
      cacheTime: 0
    };
    
    this.ensureCacheDir();
  }

  ensureCacheDir() {
    fs.mkdirSync(this.localCacheDir, { recursive: true });
  }

  calculateHash(inputs) {
    const hash = crypto.createHash('sha256');
    
    // Hash all relevant inputs
    const files = [
      inputs.dockerfile,
      ...this.getContextFiles(inputs.context)
    ];
    
    for (const file of files) {
      if (fs.existsSync(file)) {
        hash.update(fs.readFileSync(file));
      }
    }
    
    hash.update(JSON.stringify(inputs.buildArgs || {}));
    hash.update(inputs.target || 'default');
    
    return hash.digest('hex').substring(0, 16);
  }

  getContextFiles(contextPath) {
    const files = [];
    
    function walk(dir) {
      const items = fs.readdirSync(dir);
      for (const item of items) {
        const fullPath = path.join(dir, item);
        const stat = fs.statSync(fullPath);
        
        if (stat.isDirectory() && item !== 'node_modules' && item !== '.git') {
          walk(fullPath);
        } else if (stat.isFile()) {
          files.push(fullPath);
        }
      }
    }
    
    if (fs.existsSync(contextPath)) {
      walk(contextPath);
    }
    
    return files;
  }

  async tryCacheStrategies(hash, imageName) {
    console.log(`🔍 Trying cache strategies for hash: ${hash}`);
    
    // Strategy 1: Local file cache
    if (this.strategies.includes('local')) {
      const localResult = await this.tryLocalCache(hash, imageName);
      if (localResult.hit) {
        this.stats.hits.local++;
        return localResult;
      }
    }
    
    // Strategy 2: Registry cache
    if (this.strategies.includes('registry') && this.registryUrl) {
      const registryResult = await this.tryRegistryCache(hash, imageName);
      if (registryResult.hit) {
        this.stats.hits.registry++;
        return registryResult;
      }
    }
    
    // Strategy 3: Layer cache (always available)
    if (this.strategies.includes('layer')) {
      console.log(`   Layer cache: Will be used during build`);
    }
    
    this.stats.misses++;
    return { hit: false, strategy: 'none' };
  }

  async tryLocalCache(hash, imageName) {
    const cachePath = path.join(this.localCacheDir, `${hash}.tar`);
    
    if (fs.existsSync(cachePath)) {
      console.log(`   ✅ Local cache hit!`);
      try {
        const startTime = Date.now();
        execSync(`docker load -i ${cachePath}`, { stdio: 'pipe' });
        
        // Tag with desired name
        const cachedTag = `cached:${hash}`;
        execSync(`docker tag ${cachedTag} ${imageName}`, { stdio: 'pipe' });
        
        const loadTime = Date.now() - startTime;
        console.log(`      Loaded in ${loadTime}ms`);
        
        return { hit: true, strategy: 'local', time: loadTime };
      } catch (e) {
        console.error(`      Failed to load: ${e.message}`);
      }
    }
    
    return { hit: false };
  }

  async tryRegistryCache(hash, imageName) {
    const registryTag = `${this.registryUrl}/cache:${hash}`;
    
    console.log(`   Checking registry: ${registryTag}`);
    try {
      const startTime = Date.now();
      execSync(`docker pull ${registryTag}`, { stdio: 'pipe' });
      execSync(`docker tag ${registryTag} ${imageName}`, { stdio: 'pipe' });
      
      const pullTime = Date.now() - startTime;
      console.log(`   ✅ Registry cache hit! (${pullTime}ms)`);
      
      return { hit: true, strategy: 'registry', time: pullTime };
    } catch {
      console.log(`   ❌ Not in registry`);
    }
    
    return { hit: false };
  }

  async build(imageName, inputs) {
    console.log(`🔨 Building image...`);
    const startTime = Date.now();
    
    const buildCmd = this.constructBuildCommand(imageName, inputs);
    
    try {
      execSync(buildCmd, { stdio: 'inherit' });
      
      const buildTime = Date.now() - startTime;
      this.stats.buildTime += buildTime;
      
      console.log(`✅ Build completed in ${buildTime}ms`);
      return true;
    } catch (e) {
      console.error(`❌ Build failed: ${e.message}`);
      return false;
    }
  }

  constructBuildCommand(imageName, inputs) {
    const parts = [];
    
    if (this.enableBuildKit) {
      parts.push('DOCKER_BUILDKIT=1');
    }
    
    parts.push('docker', 'build');
    parts.push('-t', imageName);
    parts.push('-f', inputs.dockerfile);
    
    if (inputs.buildArgs) {
      for (const [key, value] of Object.entries(inputs.buildArgs)) {
        parts.push('--build-arg', `${key}=${value}`);
      }
    }
    
    if (inputs.target) {
      parts.push('--target', inputs.target);
    }
    
    // Add cache-from for layer cache
    if (this.strategies.includes('layer')) {
      parts.push('--cache-from', imageName);
    }
    
    parts.push(inputs.context);
    
    return parts.join(' ');
  }

  async saveToAllCaches(hash, imageName) {
    console.log(`💾 Saving to cache locations...`);
    const startTime = Date.now();
    const results = [];
    
    // Save to local cache
    if (this.strategies.includes('local')) {
      const localResult = await this.saveToLocalCache(hash, imageName);
      results.push({ strategy: 'local', success: localResult });
    }
    
    // Save to registry
    if (this.strategies.includes('registry') && this.registryUrl) {
      const registryResult = await this.saveToRegistry(hash, imageName);
      results.push({ strategy: 'registry', success: registryResult });
    }
    
    const cacheTime = Date.now() - startTime;
    this.stats.cacheTime += cacheTime;
    
    console.log(`✅ Cache save completed in ${cacheTime}ms`);
    return results;
  }

  async saveToLocalCache(hash, imageName) {
    const cachePath = path.join(this.localCacheDir, `${hash}.tar`);
    const cachedTag = `cached:${hash}`;
    
    try {
      execSync(`docker tag ${imageName} ${cachedTag}`, { stdio: 'pipe' });
      execSync(`docker save ${cachedTag} -o ${cachePath}`, { stdio: 'pipe' });
      
      const size = fs.statSync(cachePath).size;
      console.log(`   ✅ Local: ${(size / 1024 / 1024).toFixed(1)}MB`);
      
      return true;
    } catch (e) {
      console.error(`   ❌ Local save failed: ${e.message}`);
      return false;
    }
  }

  async saveToRegistry(hash, imageName) {
    const registryTag = `${this.registryUrl}/cache:${hash}`;
    
    try {
      execSync(`docker tag ${imageName} ${registryTag}`, { stdio: 'pipe' });
      execSync(`docker push ${registryTag}`, { stdio: 'pipe' });
      
      console.log(`   ✅ Registry: ${registryTag}`);
      return true;
    } catch (e) {
      console.error(`   ❌ Registry push failed: ${e.message}`);
      return false;
    }
  }

  async execute(imageName, inputs) {
    const hash = this.calculateHash(inputs);
    
    console.log(`\n🚀 Hybrid Cache Execution`);
    console.log(`   Image: ${imageName}`);
    console.log(`   Hash: ${hash}`);
    console.log(`   Strategies: ${this.strategies.join(', ')}`);
    console.log('');
    
    // Try cache strategies
    const cacheResult = await this.tryCacheStrategies(hash, imageName);
    
    if (cacheResult.hit) {
      console.log(`\n✨ Cache hit via ${cacheResult.strategy}!`);
      return { success: true, cached: true, strategy: cacheResult.strategy };
    }
    
    // Build if no cache hit
    const built = await this.build(imageName, inputs);
    if (!built) {
      return { success: false };
    }
    
    // Save to all caches
    await this.saveToAllCaches(hash, imageName);
    
    return { success: true, cached: false };
  }

  getStats() {
    const totalHits = Object.values(this.stats.hits).reduce((a, b) => a + b, 0);
    const totalRequests = totalHits + this.stats.misses;
    const hitRate = totalRequests > 0 ? (totalHits / totalRequests * 100).toFixed(1) : 0;
    
    return {
      ...this.stats,
      totalHits,
      hitRate: `${hitRate}%`
    };
  }
}

module.exports = HybridDockerCache;