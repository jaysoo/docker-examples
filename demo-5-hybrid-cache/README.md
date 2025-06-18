# Demo 5: Hybrid Caching Approach

This demo combines multiple caching strategies for optimal performance.

## What it demonstrates

1. Layer caching (Docker build cache)
2. Image caching (save/load)
3. Registry caching (fallback)
4. Build context caching
5. Intelligent cache selection

## Strategy

```
1. Check local Nx cache (fastest)
   ↓ miss
2. Check registry cache (team shared)
   ↓ miss
3. Build with layer cache
   ↓
4. Save to all cache locations
```

## Benefits

- Fastest possible cache hits
- Fallback options
- Team cache sharing
- Works in all environments

## Files

- `hybrid-cache.js` - Orchestration logic
- `cache-strategies/` - Individual strategies
- Configurable priorities

## Running

```bash
./run.sh
```