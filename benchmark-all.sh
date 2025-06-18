#!/bin/bash
set -e

echo "🏁 Docker Nx Cache Benchmark"
echo "============================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Results storage
declare -A BUILD_TIMES
declare -A CACHE_SAVE_TIMES
declare -A CACHE_LOAD_TIMES
declare -A CACHE_SIZES

# Cleanup function
cleanup() {
  echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
  docker rmi $(docker images -q "demo*-app" 2>/dev/null) 2>/dev/null || true
  docker rmi $(docker images -q "cached:*" 2>/dev/null) 2>/dev/null || true
  echo "   ✅ Cleanup complete"
}

# Run benchmarks
echo -e "${BLUE}Running benchmarks...${NC}\n"

# Demo 1: Basic Save/Load
if [ -d "demo-1-basic-save-load" ]; then
  echo -e "${BLUE}Benchmarking Demo 1: Basic Save/Load${NC}"
  cd demo-1-basic-save-load
  
  # Clean start
  rm -rf cache
  mkdir -p cache
  
  # Cold build
  START=$(date +%s)
  docker build -t bench1:test . > /dev/null 2>&1
  END=$(date +%s)
  BUILD_TIMES["save-load"]=$((END - START))
  
  # Save
  START=$(date +%s)
  docker save bench1:test -o cache/bench1.tar
  END=$(date +%s)
  CACHE_SAVE_TIMES["save-load"]=$((END - START))
  CACHE_SIZES["save-load"]=$(ls -lh cache/bench1.tar | awk '{print $5}')
  
  # Remove and load
  docker rmi bench1:test > /dev/null 2>&1
  START=$(date +%s)
  docker load -i cache/bench1.tar > /dev/null 2>&1
  END=$(date +%s)
  CACHE_LOAD_TIMES["save-load"]=$((END - START))
  
  cd ..
  echo -e "   ${GREEN}✅ Complete${NC}"
fi

# Demo 2: Nx-Style Cache
if [ -d "demo-2-nx-style-cache" ]; then
  echo -e "\n${BLUE}Benchmarking Demo 2: Nx-Style Cache${NC}"
  cd demo-2-nx-style-cache
  
  # Clean start
  rm -rf .nx-cache
  
  # Use the nx cache system
  NODE_PATH=. node -e "
    const NxDockerCache = require('./nx-docker-cache.js');
    const { execSync } = require('child_process');
    const cache = new NxDockerCache();
    
    const start = Date.now();
    execSync('docker build -t bench2:test .', { stdio: 'pipe' });
    const buildTime = Date.now() - start;
    
    const hash = cache.calculateHash({
      dockerfile: './Dockerfile',
      context: './app'
    });
    
    const saveStart = Date.now();
    cache.saveToCache(hash, 'bench2:test', {});
    const saveTime = Date.now() - saveStart;
    
    console.log(JSON.stringify({
      buildTime: Math.round(buildTime / 1000),
      saveTime: Math.round(saveTime / 1000)
    }));
  " > bench2-results.json 2>/dev/null || echo '{"buildTime": 0, "saveTime": 0}' > bench2-results.json
  
  RESULT=$(cat bench2-results.json)
  BUILD_TIMES["nx-style"]=$(echo $RESULT | jq -r '.buildTime')
  CACHE_SAVE_TIMES["nx-style"]=$(echo $RESULT | jq -r '.saveTime')
  
  # Measure cache size
  if [ -d ".nx-cache/docker" ]; then
    CACHE_SIZES["nx-style"]=$(du -sh .nx-cache/docker 2>/dev/null | awk '{print $1}' || echo "N/A")
  else
    CACHE_SIZES["nx-style"]="N/A"
  fi
  
  cd ..
  echo -e "   ${GREEN}✅ Complete${NC}"
fi

# Demo 3: Registry Cache (skip if no registry)
echo -e "\n${BLUE}Demo 3: Registry Cache${NC}"
echo "   ⏭️  Skipping (requires registry setup)"
BUILD_TIMES["registry"]="N/A"
CACHE_SAVE_TIMES["registry"]="N/A"
CACHE_LOAD_TIMES["registry"]="N/A"
CACHE_SIZES["registry"]="Network"

# Demo 4: BuildKit
if [ -d "demo-4-buildkit-cache" ]; then
  echo -e "\n${BLUE}Benchmarking Demo 4: BuildKit${NC}"
  cd demo-4-buildkit-cache
  
  # Cold build
  START=$(date +%s)
  DOCKER_BUILDKIT=1 docker build -f Dockerfile.buildkit -t bench4:test . > /dev/null 2>&1 || docker build -f Dockerfile.buildkit -t bench4:test . > /dev/null 2>&1
  END=$(date +%s)
  BUILD_TIMES["buildkit"]=$((END - START))
  
  # Warm build (layer cache)
  START=$(date +%s)
  DOCKER_BUILDKIT=1 docker build -f Dockerfile.buildkit -t bench4:test2 . > /dev/null 2>&1 || docker build -f Dockerfile.buildkit -t bench4:test2 . > /dev/null 2>&1
  END=$(date +%s)
  CACHE_LOAD_TIMES["buildkit"]=$((END - START))
  
  CACHE_SIZES["buildkit"]="Layer cache"
  
  cd ..
  echo -e "   ${GREEN}✅ Complete${NC}"
fi

# Demo 5: Hybrid
if [ -d "demo-5-hybrid-cache" ]; then
  echo -e "\n${BLUE}Benchmarking Demo 5: Hybrid${NC}"
  cd demo-5-hybrid-cache
  
  # Clean start
  rm -rf .nx-cache
  
  # Build
  START=$(date +%s)
  docker build -t bench5:test . > /dev/null 2>&1
  END=$(date +%s)
  BUILD_TIMES["hybrid"]=$((END - START))
  
  CACHE_SIZES["hybrid"]="Multiple"
  
  cd ..
  echo -e "   ${GREEN}✅ Complete${NC}"
fi

# Display results
echo -e "\n\n${GREEN}📊 Benchmark Results${NC}"
echo "===================="

echo -e "\n${BLUE}Build Times (seconds):${NC}"
printf "%-20s %10s\n" "Strategy" "Time"
printf "%-20s %10s\n" "--------" "----"
for strategy in "save-load" "nx-style" "registry" "buildkit" "hybrid"; do
  if [ "${BUILD_TIMES[$strategy]}" != "" ]; then
    printf "%-20s %10s\n" "$strategy" "${BUILD_TIMES[$strategy]}s"
  fi
done

echo -e "\n${BLUE}Cache Save Times (seconds):${NC}"
printf "%-20s %10s\n" "Strategy" "Time"
printf "%-20s %10s\n" "--------" "----"
for strategy in "save-load" "nx-style" "registry"; do
  if [ "${CACHE_SAVE_TIMES[$strategy]}" != "" ]; then
    printf "%-20s %10s\n" "$strategy" "${CACHE_SAVE_TIMES[$strategy]}s"
  fi
done

echo -e "\n${BLUE}Cache Restore Times (seconds):${NC}"
printf "%-20s %10s\n" "Strategy" "Time"
printf "%-20s %10s\n" "--------" "----"
for strategy in "save-load" "buildkit"; do
  if [ "${CACHE_LOAD_TIMES[$strategy]}" != "" ]; then
    printf "%-20s %10s\n" "$strategy" "${CACHE_LOAD_TIMES[$strategy]}s"
  fi
done

echo -e "\n${BLUE}Cache Sizes:${NC}"
printf "%-20s %10s\n" "Strategy" "Size"
printf "%-20s %10s\n" "--------" "----"
for strategy in "save-load" "nx-style" "registry" "buildkit" "hybrid"; do
  if [ "${CACHE_SIZES[$strategy]}" != "" ]; then
    printf "%-20s %10s\n" "$strategy" "${CACHE_SIZES[$strategy]}"
  fi
done

echo -e "\n${GREEN}🎯 Recommendations:${NC}"
echo "=================="
echo "1. ${BLUE}Save/Load${NC}: Best for simple, reliable caching"
echo "2. ${BLUE}Nx-Style${NC}: Best for integration with Nx workflows"
echo "3. ${BLUE}Registry${NC}: Best for team cache sharing"
echo "4. ${BLUE}BuildKit${NC}: Best for layer caching efficiency"
echo "5. ${BLUE}Hybrid${NC}: Best overall but most complex"

# Cleanup option
echo -e "\n${YELLOW}Run cleanup? (y/n)${NC}"
read -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  cleanup
fi

echo -e "\n${GREEN}✅ Benchmark complete!${NC}"