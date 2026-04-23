import React, { useState } from 'react';

const API_URL = process.env.REACT_APP_API_URL || '/api';

const fieldStyle = {
  width: '100%',
  padding: '0.6rem 0.75rem',
  border: '1px solid #ddd',
  borderRadius: 5,
  fontSize: '1rem',
  fontFamily: 'inherit',
  background: 'white',
};

export default function UploadForm({ onSuccess }) {
  const [form, setForm] = useState({ title: '', ingredients: '', steps: '' });
  const [photo, setPhoto] = useState(null);
  const [preview, setPreview] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  function handleChange(e) {
    setForm(prev => ({ ...prev, [e.target.name]: e.target.value }));
  }

  function handlePhoto(e) {
    const file = e.target.files[0];
    setPhoto(file || null);
    setPreview(file ? URL.createObjectURL(file) : null);
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const data = new FormData();
      data.append('title', form.title.trim());
      data.append('ingredients', form.ingredients.trim());
      data.append('steps', form.steps.trim());
      if (photo) data.append('photo', photo);

      const res = await fetch(`${API_URL}/recipes`, { method: 'POST', body: data });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.detail || `Server error ${res.status}`);
      }
      onSuccess();
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ maxWidth: 620, margin: '0 auto' }}>
      <h2 style={{ marginBottom: '1.5rem', color: '#b03a2e', fontSize: '1.5rem' }}>
        Share a Recipe
      </h2>

      {error && (
        <div style={{ background: '#fdecea', border: '1px solid #f5c6cb', borderRadius: 5, padding: '0.75rem 1rem', marginBottom: '1rem', color: '#721c24' }}>
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
        <div>
          <label style={{ display: 'block', marginBottom: 5, fontWeight: 600 }}>
            Recipe Title <span style={{ color: '#b03a2e' }}>*</span>
          </label>
          <input
            name="title"
            value={form.title}
            onChange={handleChange}
            required
            placeholder="e.g. Amma's Sambar"
            style={fieldStyle}
          />
        </div>

        <div>
          <label style={{ display: 'block', marginBottom: 5, fontWeight: 600 }}>
            Ingredients <span style={{ color: '#b03a2e' }}>*</span>
          </label>
          <textarea
            name="ingredients"
            value={form.ingredients}
            onChange={handleChange}
            required
            rows={6}
            placeholder="List each ingredient on a new line&#10;e.g.&#10;2 cups toor dal&#10;1 tomato, chopped&#10;1 tsp mustard seeds"
            style={{ ...fieldStyle, resize: 'vertical' }}
          />
        </div>

        <div>
          <label style={{ display: 'block', marginBottom: 5, fontWeight: 600 }}>
            Steps <span style={{ color: '#b03a2e' }}>*</span>
          </label>
          <textarea
            name="steps"
            value={form.steps}
            onChange={handleChange}
            required
            rows={7}
            placeholder="Describe each step&#10;e.g.&#10;1. Pressure cook the dal with turmeric for 3 whistles.&#10;2. Heat oil in a pan and add mustard seeds..."
            style={{ ...fieldStyle, resize: 'vertical' }}
          />
        </div>

        <div>
          <label style={{ display: 'block', marginBottom: 5, fontWeight: 600 }}>
            Photo <span style={{ color: '#999', fontWeight: 400 }}>(optional)</span>
          </label>
          <input type="file" accept="image/*" onChange={handlePhoto} style={{ fontSize: '0.95rem' }} />
          {preview && (
            <img
              src={preview}
              alt="preview"
              style={{ marginTop: '0.75rem', maxHeight: 200, borderRadius: 6, objectFit: 'cover' }}
            />
          )}
        </div>

        <button
          type="submit"
          disabled={loading}
          style={{
            padding: '0.75rem',
            background: loading ? '#999' : '#b03a2e',
            color: 'white',
            border: 'none',
            borderRadius: 6,
            fontSize: '1rem',
            fontWeight: 600,
            cursor: loading ? 'not-allowed' : 'pointer',
            transition: 'background 0.18s',
          }}
        >
          {loading ? 'Submitting…' : 'Share Recipe'}
        </button>
      </form>
    </div>
  );
}
