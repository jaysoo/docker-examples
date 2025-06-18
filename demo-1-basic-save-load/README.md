# Demo 1: Basic Docker Save/Load

This demo shows the fundamental docker save/load mechanism that can be used for caching.

## What it demonstrates

1. Building a Docker image
2. Saving the image to a tar file
3. Removing the image from Docker
4. Loading the image from the tar file
5. Verifying the image works after loading

## Files

- `app/` - Simple Node.js application
- `Dockerfile` - Basic Dockerfile
- `run.sh` - Demo script
- `cache/` - Directory where cached images are stored

## Running

```bash
./run.sh
```

## Key Commands

```bash
# Save image
docker save myapp:latest -o cache/myapp.tar

# Load image
docker load -i cache/myapp.tar
```

## Results

- Cache file size: ~170MB for a Node.js app
- Save time: ~1 second
- Load time: <1 second
- Build time (no cache): 2-3 seconds