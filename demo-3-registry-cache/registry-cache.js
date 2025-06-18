#!/usr/bin/env node
const crypto = require('crypto');
const { execSync } = require('child_process');
const fs = require('fs');

class RegistryCache {
  constructor(registryUrl = 'localhost:5000') {
    this.registryUrl = registryUrl;
  }

  calculateHash(inputs) {
    const hash = crypto.createHash('sha256');
    
    // Hash dockerfile
    if (inputs.dockerfile && fs.existsSync(inputs.dockerfile)) {
      hash.update(fs.readFileSync(inputs.dockerfile));
    }
    
    // Hash context files
    if (inputs.contextFiles) {
      for (const file of inputs.contextFiles) {
        if (fs.existsSync(file)) {
          hash.update(fs.readFileSync(file));
        }
      }
    }
    
    // Hash build args
    hash.update(JSON.stringify(inputs.buildArgs || {}));
    
    return hash.digest('hex').substring(0, 16);
  }

  getCacheTag(baseImage, hash) {
    return `${this.registryUrl}/${baseImage}:cache-${hash}`;
  }

  async checkCache(baseImage, inputs) {
    const hash = this.calculateHash(inputs);
    const cacheTag = this.getCacheTag(baseImage, hash);
    
    console.log(`🔍 Checking registry cache...`);
    console.log(`   Cache tag: ${cacheTag}`);
    
    try {
      // Try to pull the cached image
      console.log(`   Attempting to pull...`);
      execSync(`docker pull ${cacheTag}`, { stdio: 'pipe' });
      
      console.log(`✅ Cache hit! Pulled from registry`);
      
      // Tag as requested image name
      if (inputs.targetImage) {
        execSync(`docker tag ${cacheTag} ${inputs.targetImage}`);
        console.log(`   Tagged as: ${inputs.targetImage}`);
      }
      
      return { hit: true, hash, cacheTag };
    } catch (e) {
      console.log(`❌ Cache miss (not in registry)`);
      return { hit: false, hash, cacheTag };
    }
  }

  async pushToCache(imageName, hash, baseImage) {
    const cacheTag = this.getCacheTag(baseImage, hash);
    
    try {
      console.log(`📤 Pushing to registry cache...`);
      
      // Tag for cache
      execSync(`docker tag ${imageName} ${cacheTag}`);
      
      // Push to registry
      const startTime = Date.now();
      execSync(`docker push ${cacheTag}`, { stdio: 'pipe' });
      const pushTime = Date.now() - startTime;
      
      console.log(`✅ Pushed to registry cache`);
      console.log(`   Tag: ${cacheTag}`);
      console.log(`   Time: ${pushTime}ms`);
      
      // Also push latest tag
      const latestTag = `${this.registryUrl}/${baseImage}:latest`;
      execSync(`docker tag ${imageName} ${latestTag}`);
      execSync(`docker push ${latestTag}`, { stdio: 'pipe' });
      
      return true;
    } catch (e) {
      console.error(`❌ Failed to push to cache: ${e.message}`);
      return false;
    }
  }

  async listCachedImages(baseImage) {
    try {
      // List tags in registry
      const url = `http://${this.registryUrl}/v2/${baseImage}/tags/list`;
      const response = execSync(`curl -s ${url}`, { encoding: 'utf-8' });
      const data = JSON.parse(response);
      
      const cacheTags = (data.tags || []).filter(tag => tag.startsWith('cache-'));
      
      console.log(`📋 Cached images in registry:`);
      console.log(`   Repository: ${this.registryUrl}/${baseImage}`);
      console.log(`   Cache entries: ${cacheTags.length}`);
      
      for (const tag of cacheTags) {
        console.log(`   - ${tag}`);
      }
      
      return cacheTags;
    } catch (e) {
      console.error(`❌ Failed to list cache: ${e.message}`);
      return [];
    }
  }

  async cleanOldCache(baseImage, keepCount = 5) {
    const cacheTags = await this.listCachedImages(baseImage);
    
    if (cacheTags.length <= keepCount) {
      console.log(`✅ Cache within limit (${cacheTags.length}/${keepCount})`);
      return;
    }
    
    // Sort by timestamp in tag (if included) or alphabetically
    const toDelete = cacheTags.slice(0, cacheTags.length - keepCount);
    
    console.log(`🗑️  Cleaning old cache entries...`);
    for (const tag of toDelete) {
      try {
        // Delete from registry (requires delete enabled)
        console.log(`   Deleting ${tag}...`);
        // In real scenario, would use registry API to delete
      } catch (e) {
        console.error(`   Failed to delete ${tag}`);
      }
    }
  }
}

module.exports = RegistryCache;