# Simple Frontend

A React application for testing Docker deployment and backend integration.

## Features

- **API Testing Dashboard** - Test different backend endpoints
- **Real-time Backend Status** - Shows connection status with backend
- **Environment Info** - Displays current environment configuration
- **Docker Testing Checklist** - Verifies containerized deployment

## Local Development

```bash
# Install dependencies
npm install

# Start development server
npm start

# Build for production
npm run build
```

The app will be available at `http://localhost:3000`

## Environment Variables

- `REACT_APP_API_URL` - Backend API URL (default: `http://localhost:8000`)

## API Endpoints Tested

- `GET /` - Root endpoint
- `GET /health` - Health check
- `GET /info` - Service information
- `GET /test` - Test data endpoint

## Docker

```bash
# Build the image
docker build -t simple-frontend .

# Run the container
docker run -p 3000:3000 simple-frontend

# With custom backend URL
docker run -p 3000:3000 -e REACT_APP_API_URL=http://backend:8000 simple-frontend
```

## Docker Compose

The app works with docker-compose and automatically connects to the backend service.

## Testing Checklist

When running in Docker, this app tests:

- ✅ Frontend container builds and runs
- ✅ Static files (HTML, CSS, JS) are served correctly
- ✅ API calls to backend work
- ✅ Environment variables are passed correctly
- ✅ Network communication between containers
