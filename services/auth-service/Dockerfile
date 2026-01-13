FROM node:18-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY src/ ./src/

# Expose port
EXPOSE 3000

# Set environment to production
ENV NODE_ENV=production

# Run as non-root user
USER node

# Start application
CMD ["node", "src/index.js"]
