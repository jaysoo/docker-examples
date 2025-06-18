#!/bin/bash
set -e

echo "🔵 Demo 4: BuildKit Advanced Caching"
echo "==================================="

# Check BuildKit support
if ! docker buildx version &> /dev/null; then
  echo "⚠️  Docker buildx not available, trying with DOCKER_BUILDKIT=1"
  USE_BUILDX=false
else
  echo "✅ Docker buildx available"
  USE_BUILDX=true
fi

echo ""
echo "1️⃣ First build (cold cache)..."
START_TIME=$(date +%s)

if [ "$USE_BUILDX" = true ]; then
  docker buildx build \
    -f Dockerfile.buildkit \
    -t demo4-app:buildkit \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --load \
    .
else
  DOCKER_BUILDKIT=1 docker build \
    -f Dockerfile.buildkit \
    -t demo4-app:buildkit \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    .
fi

END_TIME=$(date +%s)
COLD_BUILD_TIME=$((END_TIME - START_TIME))
echo "   ✅ Cold build completed in ${COLD_BUILD_TIME}s"

echo ""
echo "2️⃣ Second build (warm cache)..."
START_TIME=$(date +%s)

if [ "$USE_BUILDX" = true ]; then
  docker buildx build \
    -f Dockerfile.buildkit \
    -t demo4-app:buildkit-cached \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --cache-from demo4-app:buildkit \
    --load \
    .
else
  DOCKER_BUILDKIT=1 docker build \
    -f Dockerfile.buildkit \
    -t demo4-app:buildkit-cached \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    .
fi

END_TIME=$(date +%s)
WARM_BUILD_TIME=$((END_TIME - START_TIME))
echo "   ✅ Warm build completed in ${WARM_BUILD_TIME}s"
echo "   ⚡ Speed improvement: $((COLD_BUILD_TIME - WARM_BUILD_TIME))s faster"

echo ""
echo "3️⃣ Testing BuildKit-cached image..."
CONTAINER_ID=$(docker run -d -p 3004:3000 demo4-app:buildkit)
sleep 2

if curl -s http://localhost:3004 > /dev/null; then
  echo "   ✅ BuildKit image works!"
  RESPONSE=$(curl -s http://localhost:3004)
  echo "   Response: $RESPONSE" | head -n 5
else
  echo "   ❌ Failed to connect"
fi

docker stop $CONTAINER_ID > /dev/null
docker rm $CONTAINER_ID > /dev/null

echo ""
echo "📊 BuildKit Cache Summary:"
echo "   - Cold build: ${COLD_BUILD_TIME}s"
echo "   - Warm build: ${WARM_BUILD_TIME}s"
echo "   - Cache mounts preserve npm cache"
echo "   - Inline cache enables layer reuse"
echo ""

# Show cache info if buildx available
if [ "$USE_BUILDX" = true ]; then
  echo "📦 BuildKit cache usage:"
  docker buildx du 2>/dev/null || echo "   Cache info not available"
fi