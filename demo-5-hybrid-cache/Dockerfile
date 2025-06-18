FROM node:18-alpine AS base
WORKDIR /app

# Dependencies
FROM base AS deps
COPY package*.json ./
RUN npm ci --only=production

# Application
FROM base AS app
COPY --from=deps /app/node_modules ./node_modules
COPY src/ ./src/

# Add cache metadata
ARG CACHE_STRATEGY="hybrid"
ARG VERSION="1.0.0"
ENV CACHE_STRATEGY=$CACHE_STRATEGY
ENV VERSION=$VERSION

EXPOSE 3000
CMD ["node", "src/server.js"]