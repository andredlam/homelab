# Simple Backend API

A simple FastAPI web server for testing Docker deployment.

## Endpoints

- `GET /` - Root endpoint with basic information
- `GET /health` - Health check endpoint (used by Docker health check)
- `GET /info` - Service information and available endpoints
- `GET /test` - Test endpoint with sample data

## Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run the server
python backend/main.py

# Or using uvicorn directly
uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

## Docker

```bash
# Build the image
docker build -t simple-backend .

# Run the container
docker run -p 8000:8000 simple-backend

# Test the endpoints
curl http://localhost:8000/
curl http://localhost:8000/health
curl http://localhost:8000/info
curl http://localhost:8000/test
```

## Environment Variables

- `ENV` - Set the environment (development, staging, production)

## Health Check

The Docker health check uses the `/health` endpoint to monitor container health.
