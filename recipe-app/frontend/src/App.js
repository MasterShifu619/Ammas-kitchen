import React, { useState } from 'react';
import RecipeDashboard from './components/RecipeDashboard';
import UploadForm from './components/UploadForm';
import './App.css';

export default function App() {
  const [view, setView] = useState('browse');
  const [refreshKey, setRefreshKey] = useState(0);

  function handleUploadSuccess() {
    setRefreshKey(k => k + 1);
    setView('browse');
  }

  return (
    <div>
      <header className="app-header">
        <h1>Amma's Kitchen</h1>
        <nav>
          <button
            className={view === 'browse' ? 'active' : ''}
            onClick={() => setView('browse')}
          >
            Browse Recipes
          </button>
          <button
            className={view === 'upload' ? 'active' : ''}
            onClick={() => setView('upload')}
          >
            Share a Recipe
          </button>
        </nav>
      </header>
      <main>
        {view === 'upload' ? (
          <UploadForm onSuccess={handleUploadSuccess} />
        ) : (
          <RecipeDashboard key={refreshKey} />
        )}
      </main>
    </div>
  );
}
