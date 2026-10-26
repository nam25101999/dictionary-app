import React, { useState, useEffect, useCallback } from 'react';
import { DefinitionData, HealthInfo, HistoryItem } from './types/dictionary';
import { fetchDefinition, fetchHealth, fetchHistory } from './services/api';

const SAMPLE_WORDS = ['computer', 'devops', 'container', 'pipeline', 'database', 'cloud'];

export const App: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [definition, setDefinition] = useState<DefinitionData | null>(null);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [health, setHealth] = useState<HealthInfo | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadHealth = useCallback(async () => {
    try {
      const data = await fetchHealth();
      setHealth(data);
    } catch {
      setHealth(null);
    }
  }, []);

  const loadHistory = useCallback(async () => {
    try {
      const data = await fetchHistory();
      setHistory(data);
    } catch {
      // Backend may be offline initially
    }
  }, []);

  useEffect(() => {
    loadHealth();
    loadHistory();
    const interval = setInterval(loadHealth, 15000);
    return () => clearInterval(interval);
  }, [loadHealth, loadHistory]);

  const handleSearch = async (wordToSearch: string) => {
    const trimmed = wordToSearch.trim();
    if (!trimmed) return;

    setLoading(true);
    setError(null);

    try {
      const result = await fetchDefinition(trimmed);
      setDefinition(result);
      setSearchTerm(result.word);
    } catch (err: unknown) {
      setDefinition(null);
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unexpected error occurred.');
      }
    } finally {
      setLoading(false);
      loadHistory();
    }
  };

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    handleSearch(searchTerm);
  };

  const onClear = () => {
    setSearchTerm('');
    setError(null);
  };

  return (
    <div className="app-container">
      {/* Header */}
      <header className="app-header">
        <div className="brand">
          <div className="brand-icon" aria-hidden="true">📖</div>
          <div>
            <h1>DevOps Dictionary</h1>
            <p>End-to-End Containerized CI/CD Practice Project</p>
          </div>
        </div>

        {/* Health status badge */}
        <div
          id="health-badge"
          className={`health-badge ${health?.status === 'UP' ? 'up' : 'down'}`}
          title={health ? `Service: ${health.service} | DB: ${health.database}` : 'Backend is unreachable'}
        >
          <span className="status-dot"></span>
          <span>{health?.status === 'UP' ? `API: Online (${health.database})` : 'API: Offline'}</span>
        </div>
      </header>

      {/* Search Input Section */}
      <section className="search-card">
        <form className="search-form" onSubmit={onSubmit}>
          <div className="search-input-wrapper">
            <input
              id="search-input"
              type="text"
              className="search-input"
              placeholder="Search an English technical term (e.g. computer, devops)..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              disabled={loading}
              autoComplete="off"
            />
            {searchTerm && (
              <button
                type="button"
                id="clear-btn"
                className="clear-btn"
                onClick={onClear}
                aria-label="Clear search input"
              >
                ✕
              </button>
            )}
          </div>

          <button
            id="search-btn"
            type="submit"
            className="submit-btn"
            disabled={loading || !searchTerm.trim()}
          >
            {loading ? (
              <>
                <span className="spinner"></span>
                <span>Searching...</span>
              </>
            ) : (
              <>
                <span>🔍</span>
                <span>Define</span>
              </>
            )}
          </button>
        </form>

        {/* Quick sample keywords */}
        <div className="quick-tags">
          <span className="quick-label">Sample words:</span>
          {SAMPLE_WORDS.map((w) => (
            <button
              key={w}
              type="button"
              className="tag-btn"
              onClick={() => {
                setSearchTerm(w);
                handleSearch(w);
              }}
            >
              {w}
            </button>
          ))}
        </div>
      </section>

      {/* Error Message */}
      {error && (
        <div id="error-banner" className="error-banner" role="alert">
          <span className="error-icon">⚠️</span>
          <div>
            <strong>Lookup Notice:</strong> {error}
          </div>
        </div>
      )}

      {/* Definition Result Card */}
      {definition && (
        <main id="result-card" className="result-card">
          <div className="result-header">
            <div>
              <h2 className="word-title">{definition.word}</h2>
              {definition.phonetic && <div className="phonetic">{definition.phonetic}</div>}
            </div>
            {definition.partOfSpeech && (
              <span className="pos-badge">{definition.partOfSpeech}</span>
            )}
          </div>

          <div className="definition-section">
            <div className="section-label">Definition</div>
            <p className="definition-text">{definition.definition}</p>
          </div>

          {definition.example && (
            <div>
              <div className="section-label">Example</div>
              <div className="example-box">"{definition.example}"</div>
            </div>
          )}
        </main>
      )}

      {/* Search History Section */}
      <section className="history-section">
        <div className="history-header">
          <h2>Recent Search History</h2>
          <button
            type="button"
            className="tag-btn"
            onClick={loadHistory}
            id="refresh-history-btn"
          >
            ↻ Refresh
          </button>
        </div>

        {history.length === 0 ? (
          <p className="empty-history">No search history yet. Try searching for a word above!</p>
        ) : (
          <div className="history-grid">
            {history.map((item) => (
              <button
                key={item.id}
                type="button"
                className="history-item"
                onClick={() => {
                  setSearchTerm(item.word);
                  handleSearch(item.word);
                }}
              >
                <span className="history-word">{item.word}</span>
                <span className={`history-status ${item.success ? 'success' : 'fail'}`}>
                  {item.success ? 'found' : 'not found'}
                </span>
              </button>
            ))}
          </div>
        )}
      </section>

      <footer className="app-footer">
        DevOps Practice Project • React + Spring Boot 3 + PostgreSQL + Docker + GitHub Actions + Jenkins
      </footer>
    </div>
  );
};

export default App;
