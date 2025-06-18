FROM node:18-alpine

WORKDIR /app

# Add build args for cache metadata
ARG CACHE_TAG
ARG REGISTRY_URL

ENV CACHE_TAG=$CACHE_TAG
ENV REGISTRY_URL=$REGISTRY_URL

COPY app/server.js .

EXPOSE 3000

CMD ["node", "server.js"]