import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './index.css';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

function App() {
  const [backendData, setBackendData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [connectionStatus, setConnectionStatus] = useState('Not checked');

  const fetchData = async (endpoint) => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get(`${API_BASE_URL}${endpoint}`);
      setBackendData(response.data);
      setConnectionStatus('Connected ✅');
    } catch (err) {
      setError(`Failed to fetch data: ${err.message}`);
      setConnectionStatus('Disconnected ❌');
      setBackendData(null);
    } finally {
      setLoading(false);
    }
  };

  const testEndpoints = [
    { name: 'Root', endpoint: '/' },
    { name: 'Health Check', endpoint: '/health' },
    { name: 'Service Info', endpoint: '/info' },
    { name: 'Test Data', endpoint: '/test' }
  ];

  useEffect(() => {
    // Auto-test connection on load
    fetchData('/health');
  }, []);

  return (
    <div className="container">
      <div className="header">
        <h1>🚀 Simple Frontend</h1>
        <p>Testing React + Backend Integration</p>
        <p><strong>Backend Status:</strong> {connectionStatus}</p>
      </div>

      <div className="card">
        <h2>API Testing Dashboard</h2>
        <p>Click any button below to test different backend endpoints:</p>
        
        <div style={{ marginBottom: '20px' }}>
          {testEndpoints.map((item, index) => (
            <button
              key={index}
              className="button"
              onClick={() => fetchData(item.endpoint)}
              disabled={loading}
            >
              {item.name}
            </button>
          ))}
        </div>

        {loading && (
          <div className="loading">
            <p>Loading data from backend...</p>
          </div>
        )}

        {error && (
          <div className="error">
            <strong>Error:</strong> {error}
          </div>
        )}

        {backendData && (
          <div className="success">
            <h3>✅ Backend Response:</h3>
            <div className="json-display">
              {JSON.stringify(backendData, null, 2)}
            </div>
          </div>
        )}
      </div>

      <div className="card">
        <h2>📋 Application Info</h2>
        <ul>
          <li><strong>Frontend:</strong> React 18.2.0</li>
          <li><strong>Backend URL:</strong> {API_BASE_URL}</li>
          <li><strong>Environment:</strong> {process.env.NODE_ENV}</li>
          <li><strong>Build Time:</strong> {new Date().toLocaleString()}</li>
        </ul>
      </div>

      <div className="card">
        <h2>🔧 Docker Testing</h2>
        <p>This React app is designed to test:</p>
        <ul>
          <li>✅ Frontend Docker container builds correctly</li>
          <li>✅ Backend API communication works</li>
          <li>✅ Environment variables are properly configured</li>
          <li>✅ Network connectivity between containers</li>
          <li>✅ Static file serving (CSS, JS)</li>
        </ul>
      </div>
    </div>
  );
}

export default App;
