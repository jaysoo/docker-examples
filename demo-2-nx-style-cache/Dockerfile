# Multi-stage Dockerfile for better caching
FROM node:18-alpine AS base
WORKDIR /app

# Dependencies stage
FROM base AS deps
COPY app/package*.json ./
RUN npm ci --only=production

# Build stage
FROM base AS build
COPY app/package*.json ./
RUN npm ci
COPY app/ .
# Could run build steps here

# Production stage
FROM base AS production
ARG APP_VERSION=1.0.0
ARG BUILD_TIME
ARG CACHE_KEY

ENV APP_VERSION=$APP_VERSION
ENV BUILD_TIME=$BUILD_TIME
ENV CACHE_KEY=$CACHE_KEY
ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app .

EXPOSE 3000
CMD ["node", "server.js"]