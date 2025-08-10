from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import os
from datetime import datetime

app = FastAPI(
    title="Simple Backend API",
    description="A simple FastAPI web server for testing",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Hello from Simple Backend!",
        "status": "running",
        "timestamp": datetime.now().isoformat(),
        "environment": os.getenv("ENV", "development")
    }

@app.get("/health")
async def health_check():
    """Health check endpoint for Docker health check"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "backend-api"
    }

@app.get("/info")
async def info():
    """Service information endpoint"""
    return {
        "service": "Simple Backend API",
        "version": "1.0.0",
        "python_version": "3.12",
        "framework": "FastAPI",
        "endpoints": [
            {"path": "/", "method": "GET", "description": "Root endpoint"},
            {"path": "/health", "method": "GET", "description": "Health check"},
            {"path": "/info", "method": "GET", "description": "Service information"},
            {"path": "/test", "method": "GET", "description": "Test endpoint"},
        ]
    }

@app.get("/test")
async def test():
    """Test endpoint"""
    return {
        "message": "Test endpoint working!",
        "data": {
            "numbers": [1, 2, 3, 4, 5],
            "text": "This is a test response",
            "boolean": True
        },
        "timestamp": datetime.now().isoformat()
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
