#!/bin/bash
set -e

echo "🚀 Docker Nx Cache Integration - Running All Demos"
echo "================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Run each demo
demos=(
  "demo-1-basic-save-load"
  "demo-2-nx-style-cache"
  "demo-3-registry-cache"
  "demo-4-buildkit-cache"
  "demo-5-hybrid-cache"
)

for demo in "${demos[@]}"; do
  echo -e "${BLUE}Running $demo...${NC}"
  if [ -d "$demo" ] && [ -f "$demo/run.sh" ]; then
    cd "$demo"
    chmod +x run.sh
    ./run.sh
    cd ..
    echo -e "${GREEN}✅ $demo completed${NC}\n"
  else
    echo -e "${YELLOW}⚠️  $demo not found or missing run.sh${NC}\n"
  fi
done

echo -e "${GREEN}🎉 All demos completed!${NC}"
echo ""
echo "Run ./benchmark-all.sh to see performance comparisons"