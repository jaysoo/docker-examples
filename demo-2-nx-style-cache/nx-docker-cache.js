#!/usr/bin/env node
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class NxDockerCache {
  constructor(cacheDir = '.nx-cache/docker') {
    this.cacheDir = cacheDir;
    this.metadataFile = path.join(cacheDir, 'metadata.json');
    this.ensureCacheDir();
  }

  ensureCacheDir() {
    fs.mkdirSync(this.cacheDir, { recursive: true });
    if (!fs.existsSync(this.metadataFile)) {
      this.saveMetadata({});
    }
  }

  loadMetadata() {
    try {
      return JSON.parse(fs.readFileSync(this.metadataFile, 'utf-8'));
    } catch {
      return {};
    }
  }

  saveMetadata(metadata) {
    fs.writeFileSync(this.metadataFile, JSON.stringify(metadata, null, 2));
  }

  calculateHash(inputs) {
    const hash = crypto.createHash('sha256');
    
    // Hash dockerfile
    if (inputs.dockerfile && fs.existsSync(inputs.dockerfile)) {
      hash.update(fs.readFileSync(inputs.dockerfile));
    }
    
    // Hash source files
    if (inputs.context && fs.existsSync(inputs.context)) {
      this.hashDirectory(hash, inputs.context);
    }
    
    // Hash additional inputs
    hash.update(JSON.stringify(inputs.buildArgs || {}));
    hash.update(inputs.target || 'default');
    
    return hash.digest('hex').substring(0, 16);
  }

  hashDirectory(hash, dir) {
    const files = fs.readdirSync(dir).sort();
    for (const file of files) {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);
      
      if (stat.isDirectory() && file !== 'node_modules' && file !== '.git') {
        this.hashDirectory(hash, filePath);
      } else if (stat.isFile()) {
        hash.update(file);
        hash.update(fs.readFileSync(filePath));
      }
    }
  }

  getCachePath(hash) {
    return path.join(this.cacheDir, `${hash}.tar`);
  }

  getCacheInfo(hash) {
    const metadata = this.loadMetadata();
    return metadata[hash];
  }

  async checkCache(inputs) {
    const hash = this.calculateHash(inputs);
    const cachePath = this.getCachePath(hash);
    const cacheInfo = this.getCacheInfo(hash);
    
    console.log(`📊 Cache key: ${hash}`);
    
    if (fs.existsSync(cachePath) && cacheInfo) {
      console.log(`✅ Cache hit!`);
      console.log(`   Cached at: ${cacheInfo.timestamp}`);
      console.log(`   Image: ${cacheInfo.imageName}`);
      console.log(`   Size: ${this.formatBytes(cacheInfo.size)}`);
      
      // Load the image
      try {
        console.log(`📦 Loading from cache...`);
        execSync(`docker load -i ${cachePath}`, { stdio: 'pipe' });
        
        // Tag with requested name if different
        if (inputs.imageName && inputs.imageName !== cacheInfo.imageName) {
          execSync(`docker tag ${cacheInfo.imageName} ${inputs.imageName}`);
        }
        
        return { hit: true, hash, cacheInfo };
      } catch (e) {
        console.error(`❌ Failed to load from cache: ${e.message}`);
      }
    }
    
    console.log(`❌ Cache miss`);
    return { hit: false, hash };
  }

  async saveToCache(hash, imageName, inputs) {
    const cachePath = this.getCachePath(hash);
    
    try {
      console.log(`💾 Saving to cache...`);
      const startTime = Date.now();
      
      execSync(`docker save ${imageName} -o ${cachePath}`, { stdio: 'pipe' });
      
      const saveTime = Date.now() - startTime;
      const stat = fs.statSync(cachePath);
      
      // Update metadata
      const metadata = this.loadMetadata();
      metadata[hash] = {
        imageName,
        timestamp: new Date().toISOString(),
        size: stat.size,
        saveTime,
        inputs: {
          dockerfile: inputs.dockerfile,
          context: inputs.context,
          buildArgs: inputs.buildArgs,
          target: inputs.target
        }
      };
      this.saveMetadata(metadata);
      
      console.log(`✅ Cached successfully`);
      console.log(`   Time: ${saveTime}ms`);
      console.log(`   Size: ${this.formatBytes(stat.size)}`);
      
      return true;
    } catch (e) {
      console.error(`❌ Failed to cache: ${e.message}`);
      return false;
    }
  }

  formatBytes(bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    let size = bytes;
    let unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return `${size.toFixed(1)} ${units[unitIndex]}`;
  }

  getCacheStats() {
    const metadata = this.loadMetadata();
    const hashes = Object.keys(metadata);
    
    let totalSize = 0;
    for (const hash of hashes) {
      const cachePath = this.getCachePath(hash);
      if (fs.existsSync(cachePath)) {
        totalSize += fs.statSync(cachePath).size;
      }
    }
    
    return {
      entries: hashes.length,
      totalSize: this.formatBytes(totalSize),
      oldestEntry: hashes.length > 0 
        ? Math.min(...hashes.map(h => new Date(metadata[h].timestamp)))
        : null
    };
  }

  clearCache() {
    const metadata = this.loadMetadata();
    const hashes = Object.keys(metadata);
    
    let removed = 0;
    for (const hash of hashes) {
      const cachePath = this.getCachePath(hash);
      if (fs.existsSync(cachePath)) {
        fs.unlinkSync(cachePath);
        removed++;
      }
    }
    
    this.saveMetadata({});
    console.log(`🗑️  Cleared ${removed} cache entries`);
  }
}

// Export for use in other scripts
module.exports = NxDockerCache;

// CLI interface
if (require.main === module) {
  const cache = new NxDockerCache();
  const command = process.argv[2];
  
  switch (command) {
    case 'stats':
      const stats = cache.getCacheStats();
      console.log('📊 Cache Statistics:');
      console.log(`   Entries: ${stats.entries}`);
      console.log(`   Total size: ${stats.totalSize}`);
      break;
      
    case 'clear':
      cache.clearCache();
      break;
      
    default:
      console.log('Usage: nx-docker-cache.js [stats|clear]');
  }
}