FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY app/package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application
COPY app/ .

EXPOSE 3000

CMD ["node", "server.js"]