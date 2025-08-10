# Build stage
FROM node:18-alpine AS build

# Set working directory
WORKDIR /app

# Copy package files for better caching
COPY ./frontend/package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY ./frontend/ ./

# Build the React app
RUN npm run build

# Production stage
FROM bitnami/nginx:1.29.0

# Copy built React app to nginx serve directory
COPY --from=build /app/build /app/build

# Copy custom nginx configuration
COPY ./frontend/nginx.conf /opt/bitnami/nginx/conf/server_blocks/default.conf

# Expose port 80
EXPOSE 80

# Run nginx
CMD ["nginx", "-g", "daemon off;"]