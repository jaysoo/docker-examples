# Docker Nx Cache Integration Demo

This demo shows multiple approaches for integrating Docker builds with Nx cache.

## Quick Start

```bash
cd tmp/docker-nx-cache-demo
./run-all-demos.sh
```

## Demos Included

### 1. Basic Docker Save/Load (`demo-1-basic-save-load/`)
Shows the fundamental docker save/load mechanism for caching images.

### 2. Nx-Style Caching (`demo-2-nx-style-cache/`)
Implements Nx-style hash-based caching with docker images.

### 3. Registry-Based Caching (`demo-3-registry-cache/`)
Demonstrates using a local registry for caching (no external dependencies).

### 4. Layer Caching with BuildKit (`demo-4-buildkit-cache/`)
Shows advanced layer caching options (where supported).

### 5. Hybrid Approach (`demo-5-hybrid-cache/`)
Combines multiple caching strategies for optimal performance.

### 6. Real Nx Integration (`demo-6-nx-integration/`)
A complete Nx workspace with Docker caching integrated.

## Running Individual Demos

Each demo has its own README with specific instructions:

```bash
cd demo-1-basic-save-load
./run.sh
```

## Performance Comparison

Run the benchmark script to compare all approaches:

```bash
./benchmark-all.sh
```

## Key Findings Summary

1. **Docker save/load**: Most reliable, ~170MB cache files
2. **Registry cache**: Fast with local registry, good for teams
3. **BuildKit cache**: Most efficient but requires specific setup
4. **Hybrid**: Best overall but most complex

## Files Structure

```
docker-nx-cache-demo/
├── README.md (this file)
├── run-all-demos.sh
├── benchmark-all.sh
├── demo-1-basic-save-load/
├── demo-2-nx-style-cache/
├── demo-3-registry-cache/
├── demo-4-buildkit-cache/
├── demo-5-hybrid-cache/
└── demo-6-nx-integration/
```