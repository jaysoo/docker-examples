const { execSync } = require('child_process');
const { existsSync, mkdirSync, statSync } = require('fs');
const { join, dirname } = require('path');
const crypto = require('crypto');

/**
 * Nx Executor for Docker builds with caching
 */
async function dockerBuildExecutor(options, context) {
  const { logger } = context;
  
  logger.info(`Executing docker-build for ${context.projectName}`);
  
  // Determine image name
  const imageName = options.imageName || 
    `${context.projectName}:${context.targetName}`;
  
  // Check if caching is enabled
  if (options.cache !== false && context.isLocal) {
    const cacheResult = await checkCache(options, context, imageName);
    if (cacheResult.hit) {
      logger.info(`Cache hit! Restored from ${cacheResult.source}`);
      
      if (options.push) {
        await pushImage(imageName, options, logger);
      }
      
      return { success: true, cached: true };
    }
  }
  
  // Build the image
  const buildSuccess = await buildImage(imageName, options, context, logger);
  if (!buildSuccess) {
    return { success: false };
  }
  
  // Save to cache if enabled
  if (options.cache !== false && context.isLocal) {
    await saveToCache(imageName, options, context, logger);
  }
  
  // Push if requested
  if (options.push) {
    const pushSuccess = await pushImage(imageName, options, logger);
    if (!pushSuccess) {
      return { success: false };
    }
  }
  
  return { success: true, cached: false };
}

/**
 * Calculate cache key based on inputs
 */
function calculateCacheKey(options, context) {
  const hash = crypto.createHash('sha256');
  
  // Include all cache inputs
  const inputs = {
    dockerfile: options.dockerfile,
    context: options.context,
    buildArgs: options.buildArgs || {},
    target: options.target,
    platform: options.platform,
    // Include project graph dependencies
    projectDeps: context.projectGraph?.dependencies[context.projectName] || []
  };
  
  hash.update(JSON.stringify(inputs));
  
  // Hash file contents
  const dockerfilePath = join(context.root, context.workspace.projects[context.projectName].root, options.dockerfile);
  if (existsSync(dockerfilePath)) {
    const content = require('fs').readFileSync(dockerfilePath, 'utf-8');
    hash.update(content);
  }
  
  return hash.digest('hex').substring(0, 16);
}

/**
 * Check for cached image
 */
async function checkCache(options, context, imageName) {
  const cacheKey = calculateCacheKey(options, context);
  const cacheDir = join(context.root, 'node_modules/.cache/nx-docker');
  const cachePath = join(cacheDir, `${cacheKey}.tar`);
  
  context.logger.debug(`Cache key: ${cacheKey}`);
  
  // Check local cache
  if (existsSync(cachePath)) {
    try {
      context.logger.debug(`Loading from local cache: ${cachePath}`);
      execSync(`docker load -i ${cachePath}`, { stdio: 'pipe' });
      
      // Tag with requested name
      const cachedTag = `nx-cached:${cacheKey}`;
      execSync(`docker tag ${cachedTag} ${imageName}`, { stdio: 'pipe' });
      
      return { hit: true, source: 'local' };
    } catch (e) {
      context.logger.warn(`Failed to load from cache: ${e.message}`);
    }
  }
  
  // Check Nx Cloud cache if available
  if (context.nxCloud && options.cache !== false) {
    // Nx Cloud would handle this automatically
    context.logger.debug('Checking Nx Cloud cache...');
  }
  
  return { hit: false };
}

/**
 * Build Docker image
 */
async function buildImage(imageName, options, context, logger) {
  const projectRoot = context.workspace.projects[context.projectName].root;
  const dockerfilePath = join(projectRoot, options.dockerfile);
  const contextPath = join(projectRoot, options.context);
  
  // Construct build command
  const buildArgs = [];
  buildArgs.push('docker', 'build');
  buildArgs.push('-t', imageName);
  buildArgs.push('-f', dockerfilePath);
  
  // Add build arguments
  if (options.buildArgs) {
    Object.entries(options.buildArgs).forEach(([key, value]) => {
      buildArgs.push('--build-arg', `${key}=${value}`);
    });
  }
  
  // Add target if specified
  if (options.target) {
    buildArgs.push('--target', options.target);
  }
  
  // Add platform if specified
  if (options.platform) {
    buildArgs.push('--platform', options.platform);
  }
  
  // Add cache-from if specified
  if (options.cacheFrom) {
    options.cacheFrom.forEach(cache => {
      buildArgs.push('--cache-from', cache);
    });
  }
  
  // Add labels for Nx tracking
  buildArgs.push('--label', `nx.project=${context.projectName}`);
  buildArgs.push('--label', `nx.target=${context.targetName}`);
  
  // Add context path
  buildArgs.push(contextPath);
  
  const command = buildArgs.join(' ');
  logger.info(`Building Docker image: ${imageName}`);
  logger.debug(`Command: ${command}`);
  
  try {
    execSync(command, { 
      stdio: 'inherit',
      cwd: context.root 
    });
    return true;
  } catch (e) {
    logger.error(`Docker build failed: ${e.message}`);
    return false;
  }
}

/**
 * Save image to cache
 */
async function saveToCache(imageName, options, context, logger) {
  const cacheKey = calculateCacheKey(options, context);
  const cacheDir = join(context.root, 'node_modules/.cache/nx-docker');
  const cachePath = join(cacheDir, `${cacheKey}.tar`);
  
  // Ensure cache directory exists
  mkdirSync(cacheDir, { recursive: true });
  
  try {
    // Tag for caching
    const cachedTag = `nx-cached:${cacheKey}`;
    execSync(`docker tag ${imageName} ${cachedTag}`, { stdio: 'pipe' });
    
    // Save image
    logger.debug(`Saving to cache: ${cachePath}`);
    execSync(`docker save ${cachedTag} -o ${cachePath}`, { stdio: 'pipe' });
    
    const size = statSync(cachePath).size;
    logger.info(`Cached Docker image (${(size / 1024 / 1024).toFixed(1)}MB)`);
    
    // Save metadata
    const metadata = {
      cacheKey,
      imageName,
      timestamp: new Date().toISOString(),
      size,
      options
    };
    
    const metadataPath = cachePath.replace('.tar', '.json');
    require('fs').writeFileSync(metadataPath, JSON.stringify(metadata, null, 2));
    
    return true;
  } catch (e) {
    logger.error(`Failed to cache image: ${e.message}`);
    return false;
  }
}

/**
 * Push image to registry
 */
async function pushImage(imageName, options, logger) {
  const pushTag = options.registry 
    ? `${options.registry}/${imageName}`
    : imageName;
  
  try {
    if (pushTag !== imageName) {
      execSync(`docker tag ${imageName} ${pushTag}`, { stdio: 'pipe' });
    }
    
    logger.info(`Pushing image: ${pushTag}`);
    execSync(`docker push ${pushTag}`, { stdio: 'inherit' });
    
    return true;
  } catch (e) {
    logger.error(`Failed to push image: ${e.message}`);
    return false;
  }
}

module.exports = dockerBuildExecutor;