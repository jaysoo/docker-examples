#!/bin/bash
set -e

echo "🔵 Demo 1: Basic Docker Save/Load"
echo "================================="

# Create cache directory
mkdir -p cache

# Step 1: Build the image
echo ""
echo "1️⃣ Building Docker image..."
START_TIME=$(date +%s)
docker build -t demo1-app:latest . > /dev/null 2>&1
END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))
echo "   ✅ Built in ${BUILD_TIME}s"

# Step 2: Save the image
echo ""
echo "2️⃣ Saving image to cache..."
START_TIME=$(date +%s)
docker save demo1-app:latest -o cache/demo1-app.tar
END_TIME=$(date +%s)
SAVE_TIME=$((END_TIME - START_TIME))
CACHE_SIZE=$(ls -lh cache/demo1-app.tar | awk '{print $5}')
echo "   ✅ Saved in ${SAVE_TIME}s (Size: $CACHE_SIZE)"

# Step 3: Remove the image
echo ""
echo "3️⃣ Removing image from Docker..."
docker rmi demo1-app:latest > /dev/null 2>&1
echo "   ✅ Image removed"

# Step 4: Verify it's gone
echo ""
echo "4️⃣ Verifying image is removed..."
if ! docker images | grep -q "demo1-app"; then
  echo "   ✅ Confirmed: Image not in Docker"
else
  echo "   ❌ Error: Image still exists"
fi

# Step 5: Load from cache
echo ""
echo "5️⃣ Loading image from cache..."
START_TIME=$(date +%s)
docker load -i cache/demo1-app.tar > /dev/null 2>&1
END_TIME=$(date +%s)
LOAD_TIME=$((END_TIME - START_TIME))
echo "   ✅ Loaded in ${LOAD_TIME}s"

# Step 6: Test the loaded image
echo ""
echo "6️⃣ Testing loaded image..."
CONTAINER_ID=$(docker run -d -p 3001:3000 demo1-app:latest)
sleep 2
if curl -s http://localhost:3001 > /dev/null; then
  echo "   ✅ Image works correctly!"
  RESPONSE=$(curl -s http://localhost:3001 | head -n 5)
  echo "   Response preview:"
  echo "$RESPONSE" | sed 's/^/     /'
else
  echo "   ❌ Failed to connect to container"
fi

# Cleanup
docker stop $CONTAINER_ID > /dev/null 2>&1
docker rm $CONTAINER_ID > /dev/null 2>&1

echo ""
echo "📊 Performance Summary:"
echo "   - Initial build: ${BUILD_TIME}s"
echo "   - Save to cache: ${SAVE_TIME}s"
echo "   - Load from cache: ${LOAD_TIME}s"
echo "   - Cache size: $CACHE_SIZE"
echo ""