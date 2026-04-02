import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import './App.css';

const API_BASE = process.env.REACT_APP_API_URL || 'http://localhost:8080';

// ============================================
// 🎨 DESIGN SYSTEM - Clean Dark Theme
// ============================================

function App() {
  const [url, setUrl] = useState('');
  const [customAlias, setCustomAlias] = useState('');
  const [expiryDays, setExpiryDays] = useState('');
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const [copied, setCopied] = useState(false);

  const isValidUrl = (str) => {
    try {
      new URL(str);
      return true;
    } catch {
      return false;
    }
  };

  const inputError = url.length > 0 && !isValidUrl(url);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!url.trim() || inputError) return;

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
        throw new Error(errorData.message || `Request failed`);
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
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  return (
    <div className="app-container">
      {/* Subtle animated background */}
      <div className="bg-gradient" />
      <div className="bg-blob bg-blob-1" />
      <div className="bg-blob bg-blob-2" />

      {/* Main content */}
      <div className="main-content">
        {/* Header */}
        <motion.header
          className="header"
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <div className="logo">
            <div className="logo-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path strokeLinecap="round" strokeLinejoin="round" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
              </svg>
            </div>
            <span className="logo-text">LinkForge</span>
          </div>
          <p className="tagline">Transform URLs into compact, shareable links</p>
        </motion.header>

        {/* Main Card */}
        <motion.main
          className="card"
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.1 }}
        >
          <form onSubmit={handleSubmit} className="form">
            {/* URL Input Section */}
            <div className="input-section">
              <label className="input-label">Destination URL</label>
              <div className={`input-wrapper ${inputError ? 'input-error' : ''}`}>
                <div className="input-icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                  </svg>
                </div>
                <input
                  type="text"
                  placeholder="https://example.com/your-long-url"
                  value={url}
                  onChange={(e) => setUrl(e.target.value)}
                  required
                  disabled={loading}
                  className="input-field"
                />
              </div>
              {inputError && (
                <p className="error-text">Please enter a valid URL</p>
              )}
            </div>

            {/* Options Row */}
            <div className="options-row">
              {/* Custom Alias */}
              <div className="option-group">
                <label className="input-label">
                  Custom Alias
                  <span className="optional-label">optional</span>
                </label>
                <div className="input-wrapper">
                  <div className="input-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14" />
                    </svg>
                  </div>
                  <input
                    type="text"
                    placeholder="my-link"
                    value={customAlias}
                    onChange={(e) => setCustomAlias(e.target.value)}
                    disabled={loading}
                    maxLength={20}
                    className="input-field"
                  />
                </div>
              </div>

              {/* Expiry Days */}
              <div className="option-group">
                <label className="input-label">
                  Expires In
                  <span className="optional-label">optional</span>
                </label>
                <div className="input-wrapper">
                  <div className="input-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                  <input
                    type="number"
                    placeholder="Days"
                    value={expiryDays}
                    onChange={(e) => setExpiryDays(e.target.value)}
                    disabled={loading}
                    min="1"
                    max="365"
                    className="input-field"
                  />
                </div>
              </div>
            </div>

            {/* Submit Button */}
            <motion.button
              type="submit"
              disabled={loading || !url.trim() || inputError}
              className={`submit-btn ${loading ? 'submit-btn-loading' : ''}`}
              whileHover={!loading ? { scale: 1.01 } : {}}
              whileTap={!loading ? { scale: 0.99 } : {}}
            >
              {loading ? (
                <>
                  <span className="spinner" />
                  <span>Creating link...</span>
                </>
              ) : (
                <>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                  <span>Shorten URL</span>
                </>
              )}
            </motion.button>
          </form>

          {/* Error Message */}
          <AnimatePresence>
            {error && (
              <motion.div
                className="message message-error"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: 10 }}
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span>{error}</span>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Result */}
          <AnimatePresence>
            {result && !loading && (
              <motion.div
                className="result-card"
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ type: 'spring', damping: 20, stiffness: 300 }}
              >
                <div className="result-header">
                  <div className="result-status">
                    <span className="status-dot" />
                    <span>Link Created</span>
                  </div>
                </div>

                <div className="result-url-container">
                  <div className="result-url-info">
                    <span className="result-label">Your Short Link</span>
                    <a
                      href={result.shortUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="result-url"
                    >
                      {result.shortUrl}
                    </a>
                  </div>
                  <motion.button
                    onClick={copyToClipboard}
                    className={`copy-btn ${copied ? 'copy-btn-success' : ''}`}
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95 }}
                  >
                    {copied ? (
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                      </svg>
                    ) : (
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path strokeLinecap="round" strokeLinejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                      </svg>
                    )}
                  </motion.button>
                </div>

                <div className="result-stats">
                  <div className="stat">
                    <span className="stat-label">Original</span>
                    <span className="stat-value">{result.originalUrl.length > 25 ? result.originalUrl.substring(0, 25) + '...' : result.originalUrl}</span>
                  </div>
                  {result.expiry && (
                    <div className="stat">
                      <span className="stat-label">Expires</span>
                      <span className="stat-value">{new Date(result.expiry).toLocaleDateString()}</span>
                    </div>
                  )}
                  <div className="stat">
                    <span className="stat-label">Clicks</span>
                    <span className="stat-value">{result.clickCount || 0}</span>
                  </div>
                </div>

                {copied && (
                  <motion.p
                    className="copied-text"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                  >
                    Copied to clipboard!
                  </motion.p>
                )}
              </motion.div>
            )}
          </AnimatePresence>
        </motion.main>

        {/* Footer */}
        <motion.footer
          className="footer"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.5 }}
        >
          Fast, secure, and free forever
        </motion.footer>
      </div>
    </div>
  );
}

export default App;
