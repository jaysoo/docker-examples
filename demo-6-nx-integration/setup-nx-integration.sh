#!/bin/bash
set -e

echo "🔵 Demo 6: Nx Integration Setup"
echo "=============================="
echo ""

echo "📁 Creating Nx executor structure..."
echo ""

# Show the executor files
echo "1️⃣ Executor Schema (docker-build-executor/schema.json):"
echo "   Defines the options available for the executor"
cat docker-build-executor/schema.json | head -20
echo "   ..."

echo ""
echo "2️⃣ Executor Implementation (docker-build-executor/impl.js):"
echo "   Contains the caching logic"
echo "   - Calculates hash from inputs"
echo "   - Checks local cache"
echo "   - Saves/loads Docker images"
echo "   - Integrates with Nx Cloud"

echo ""
echo "3️⃣ Example Project Configuration (example-project.json):"
cat example-project.json | grep -A 15 '"docker-build"'

echo ""
echo "📋 Integration Steps:"
echo ""
echo "1. Copy executor to your Nx workspace:"
echo "   cp -r docker-build-executor /path/to/workspace/tools/executors/"
echo ""
echo "2. Register in workspace.json or nx.json:"
echo '   "executors": {'
echo '     "docker-build": {'
echo '       "implementation": "./tools/executors/docker-build/impl",'
echo '       "schema": "./tools/executors/docker-build/schema.json"'
echo '     }'
echo '   }'
echo ""
echo "3. Add to project.json:"
echo '   "docker-build": {'
echo '     "executor": "@myorg/tools:docker-build",'
echo '     "options": { ... }'
echo '   }'
echo ""
echo "4. Run with caching:"
echo "   nx docker-build my-app"
echo "   nx affected --target=docker-build"
echo ""

echo "🔧 Advanced Features:"
echo ""
echo "- Cache Inputs: Automatically includes Dockerfile and context files"
echo "- Dependency Graph: Respects project dependencies"
echo "- Affected Builds: Only rebuilds changed projects"
echo "- Parallel Execution: Build multiple images concurrently"
echo "- Nx Cloud: Works with remote caching"
echo ""

echo "💡 Tips:"
echo ""
echo "1. Configure cache inputs in nx.json:"
echo '   "targetDefaults": {'
echo '     "docker-build": {'
echo '       "inputs": ['
echo '         "production",'
echo '         "{projectRoot}/Dockerfile",'
echo '         "{projectRoot}/docker/**/*"'
echo '       ]'
echo '     }'
echo '   }'
echo ""
echo "2. Use with CI/CD:"
echo "   nx affected --target=docker-build --base=main"
echo ""
echo "3. Combine with other targets:"
echo "   nx run-many --target=build,docker-build,docker-push"
echo ""

echo "✅ Nx integration example ready!"
echo ""
echo "This demonstrates how Docker caching fits naturally into Nx workflows."