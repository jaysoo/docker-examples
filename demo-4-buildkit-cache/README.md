# Demo 4: BuildKit Advanced Caching

This demo shows advanced BuildKit caching features (where available).

## What it demonstrates

1. BuildKit inline cache
2. Cache mount for package managers
3. Layer caching optimization
4. Build-time cache mounts
5. Multi-stage build caching

## Requirements

- Docker with BuildKit support
- May need Docker Desktop with containerd enabled

## Cache Types

1. **Inline Cache**: Embeds cache metadata in the image
2. **Registry Cache**: Stores cache separately in registry
3. **Local Cache**: Exports cache to local directory
4. **Cache Mounts**: Persistent directories across builds

## Running

```bash
./run.sh
```

## Key Features

- RUN --mount=type=cache for package managers
- Proper layer ordering for optimal caching
- BuildKit-specific optimizations