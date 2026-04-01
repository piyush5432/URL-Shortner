import React, { useState } from 'react';
import './App.css';

const API_BASE = process.env.REACT_APP_API_URL || 'http://localhost:8080';

function App() {
  const [url, setUrl] = useState('');
  const [customAlias, setCustomAlias] = useState('');
  const [expiryDays, setExpiryDays] = useState('');
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    setResult(null);
    setLoading(true);

    try {
      const requestBody = { url };
      if (customAlias.trim()) requestBody.customAlias = customAlias.trim();
      if (expiryDays) requestBody.expiryDays = parseInt(expiryDays, 10);

      const response = await fetch(`${API_BASE}/shorten`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.message || `HTTP ${response.status}`);
      }

      const data = await response.json();
      setResult(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const copyToClipboard = () => {
    if (result?.shortUrl) {
      navigator.clipboard.writeText(result.shortUrl);
    }
  };

  return (
    <div className="app">
      <div className="container">
        <h1>URL Shortener</h1>
        <p className="subtitle">Create short, memorable links in seconds</p>

        <form onSubmit={handleSubmit} className="url-form">
          <div className="input-group">
            <input
              type="text"
              placeholder="Enter your long URL here..."
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              required
              className="url-input"
            />
          </div>

          <div className="options-row">
            <input
              type="text"
              placeholder="Custom alias (optional)"
              value={customAlias}
              onChange={(e) => setCustomAlias(e.target.value)}
              className="option-input"
              maxLength={20}
            />
            <input
              type="number"
              placeholder="Expiry days (optional)"
              value={expiryDays}
              onChange={(e) => setExpiryDays(e.target.value)}
              className="option-input"
              min="1"
              max="365"
            />
          </div>

          <button type="submit" disabled={loading} className="submit-btn">
            {loading ? 'Shortening...' : 'Shorten URL'}
          </button>
        </form>

        {error && (
          <div className="message error">
            <span className="icon">!</span>
            {error}
          </div>
        )}

        {result && (
          <div className="result-card">
            <p className="result-label">Your shortened URL:</p>
            <div className="result-url-row">
              <a href={result.shortUrl} target="_blank" rel="noopener noreferrer" className="result-url">
                {result.shortUrl}
              </a>
              <button onClick={copyToClipboard} className="copy-btn" title="Copy to clipboard">
                Copy
              </button>
            </div>
            <div className="result-details">
              <span><strong>Original:</strong> {result.originalUrl.substring(0, 50)}{result.originalUrl.length > 50 ? '...' : ''}</span>
              {result.expiry && <span><strong>Expires:</strong> {new Date(result.expiry).toLocaleDateString()}</span>}
              <span><strong>Clicks:</strong> {result.clickCount}</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default App;
