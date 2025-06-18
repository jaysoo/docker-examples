# Demo 6: Real Nx Integration

This demo shows how to integrate Docker caching into a real Nx workspace.

## What it demonstrates

1. Custom Nx executor for Docker builds
2. Integration with Nx task pipeline
3. Cache inputs configuration
4. Remote caching compatibility
5. Affected builds optimization

## Structure

```
executors/
  docker-build/
    schema.json      # Executor configuration
    impl.js          # Implementation
    
project.json         # Nx project config with docker target
```

## Usage

In an Nx workspace:

```json
{
  "targets": {
    "docker-build": {
      "executor": "@myorg/docker:build",
      "options": {
        "dockerfile": "Dockerfile",
        "context": ".",
        "push": false
      },
      "cache": true
    }
  }
}
```

## Features

- Respects Nx cache inputs
- Works with nx affected
- Supports Nx Cloud
- Parallel builds
- Smart cache invalidation

## Running

```bash
./setup-nx-integration.sh
```

This will create example files showing proper Nx integration.