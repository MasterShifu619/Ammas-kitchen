import React, { useEffect, useState } from 'react';

const API_URL = process.env.REACT_APP_API_URL || '/api';

function RecipeCard({ recipe }) {
  const [expanded, setExpanded] = useState(false);

  return (
    <div style={{
      background: 'white',
      borderRadius: 8,
      boxShadow: '0 2px 10px rgba(0,0,0,0.08)',
      overflow: 'hidden',
      display: 'flex',
      flexDirection: 'column',
    }}>
      {recipe.image_url ? (
        <img
          src={recipe.image_url}
          alt={recipe.title}
          style={{ width: '100%', height: 200, objectFit: 'cover' }}
        />
      ) : (
        <div style={{
          width: '100%', height: 200,
          background: 'linear-gradient(135deg, #f5e6d3 0%, #edd5b3 100%)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: '3.5rem',
        }}>
          🍲
        </div>
      )}

      <div style={{ padding: '1rem', flex: 1, display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
        <h3 style={{ color: '#b03a2e', fontSize: '1.1rem' }}>{recipe.title}</h3>
        <p style={{ fontSize: '0.78rem', color: '#aaa' }}>
          {new Date(recipe.created_at).toLocaleDateString('en-US', {
            year: 'numeric', month: 'long', day: 'numeric',
          })}
        </p>

        <button
          onClick={() => setExpanded(v => !v)}
          style={{
            marginTop: 'auto',
            padding: '0.4rem 0.9rem',
            background: 'none',
            border: '1.5px solid #b03a2e',
            color: '#b03a2e',
            borderRadius: 5,
            cursor: 'pointer',
            fontWeight: 600,
            fontSize: '0.88rem',
            alignSelf: 'flex-start',
          }}
        >
          {expanded ? 'Hide Details' : 'View Recipe'}
        </button>

        {expanded && (
          <div style={{ marginTop: '0.75rem', borderTop: '1px solid #f0e0d0', paddingTop: '0.75rem' }}>
            <h4 style={{ marginBottom: '0.4rem', fontSize: '0.95rem', color: '#555' }}>Ingredients</h4>
            <pre style={{ whiteSpace: 'pre-wrap', fontSize: '0.88rem', color: '#444', lineHeight: 1.6, marginBottom: '1rem' }}>
              {recipe.ingredients}
            </pre>
            <h4 style={{ marginBottom: '0.4rem', fontSize: '0.95rem', color: '#555' }}>Steps</h4>
            <pre style={{ whiteSpace: 'pre-wrap', fontSize: '0.88rem', color: '#444', lineHeight: 1.6 }}>
              {recipe.steps}
            </pre>
          </div>
        )}
      </div>
    </div>
  );
}

export default function RecipeDashboard() {
  const [recipes, setRecipes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetch(`${API_URL}/recipes`)
      .then(r => {
        if (!r.ok) throw new Error(`Server error ${r.status}`);
        return r.json();
      })
      .then(data => { setRecipes(data); setLoading(false); })
      .catch(err => { setError(err.message); setLoading(false); });
  }, []);

  if (loading) {
    return (
      <p style={{ textAlign: 'center', marginTop: '3rem', color: '#888', fontSize: '1.1rem' }}>
        Loading recipes…
      </p>
    );
  }

  if (error) {
    return (
      <p style={{ textAlign: 'center', marginTop: '3rem', color: '#b03a2e', fontSize: '1.05rem' }}>
        {error}
      </p>
    );
  }

  if (!recipes.length) {
    return (
      <div style={{ textAlign: 'center', marginTop: '4rem', color: '#888' }}>
        <div style={{ fontSize: '4rem', marginBottom: '1rem' }}>🍳</div>
        <p style={{ fontSize: '1.15rem' }}>No recipes yett. Be the first to share one!</p>
      </div>
    );
  }

  return (
    <div>
      <h2 style={{ marginBottom: '1.5rem', color: '#b03a2e', fontSize: '1.5rem' }}>
        All Recipes ({recipes.length})
      </h2>
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fill, minmax(290px, 1fr))',
        gap: '1.5rem',
      }}>
        {recipes.map(r => <RecipeCard key={r.id} recipe={r} />)}
      </div>
    </div>
  );
}
