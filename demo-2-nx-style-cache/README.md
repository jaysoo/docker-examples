# Demo 2: Nx-Style Hash-Based Caching

This demo implements Nx-style hash-based caching for Docker builds.

## What it demonstrates

1. Computing hash based on inputs (Dockerfile, source files, dependencies)
2. Checking cache before building
3. Storing images with hash-based naming
4. Simulating cache hits/misses
5. Handling multiple variants

## Features

- Hash-based cache keys (like Nx)
- Cache metadata tracking
- Multiple image variants
- Cache statistics

## Files

- `nx-docker-cache.js` - Nx-style caching implementation
- `app/` - Application source
- `Dockerfile` - Multi-stage Dockerfile
- `.nx-cache/` - Local cache directory (similar to .nx/cache)

## Running

```bash
./run.sh
```

## Cache Structure

```
.nx-cache/
├── docker/
│   ├── metadata.json
│   ├── [hash1].tar
│   ├── [hash1].json
│   ├── [hash2].tar
│   └── [hash2].json
```

## Key Concepts

- Cache key = hash(dockerfile + sources + dependencies)
- Metadata includes build time, size, dependencies
- Can integrate with Nx Cloud for remote caching