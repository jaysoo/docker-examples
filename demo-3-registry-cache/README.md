# Demo 3: Registry-Based Caching

This demo shows how to use a Docker registry (local or remote) for caching.

## What it demonstrates

1. Running a local Docker registry
2. Pushing images with cache tags
3. Pulling cached images instead of building
4. Registry-based cache sharing (team scenarios)
5. Cleaning up old cache entries

## Advantages

- Works great with Nx Cloud
- Shared cache across team/CI
- No local storage needed
- Native Docker solution

## Files

- `run.sh` - Demo script with local registry
- `registry-cache.js` - Registry caching logic
- `docker-compose.yml` - Local registry setup

## Cache Pattern

```bash
# Cache tag format
registry.com/myapp:cache-[hash]

# Also tag as latest
registry.com/myapp:latest
```

## Running

```bash
./run.sh
```

This will:
1. Start a local registry (localhost:5000)
2. Build and push images with cache tags
3. Demonstrate cache hits from registry
4. Show team sharing scenarios