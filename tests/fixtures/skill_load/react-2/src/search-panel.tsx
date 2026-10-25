import { useState, type FormEvent } from 'react';

type SearchResult = { id: string; title: string; url: string };

type SearchState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'failed'; error: Error }
  | { status: 'done'; results: SearchResult[] };

export function SearchPanel() {
  const [query, setQuery] = useState('');
  const [search, setSearch] = useState<SearchState>({ status: 'idle' });

  async function runSearch(text: string) {
    setSearch({ status: 'loading' });

    try {
      const response = await fetch(`/api/search?q=${encodeURIComponent(text)}`);

      if (!response.ok) {
        throw new Error(`Search failed with status ${response.status}`);
      }

      const data: unknown = await response.json();

      if (!Array.isArray(data) || !data.every(isSearchResult)) {
        throw new Error('The search response has an unexpected shape');
      }

      setSearch({ status: 'done', results: data });
    } catch (error) {
      setSearch({
        status: 'failed',
        error: error instanceof Error ? error : new Error(String(error)),
      });
    }
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    void runSearch(query);
  }

  const isLoading = search.status === 'loading';
  const errorMessage = search.status === 'failed' ? search.error.message : null;
  const results = search.status === 'done' ? search.results : null;

  return (
    <div>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          value={query}
          onChange={(event) => {
            setQuery(event.target.value);
          }}
        />
        <button type="submit">Search</button>
      </form>

      {isLoading && <p>Loading…</p>}

      {errorMessage !== null && <p role="alert">{errorMessage}</p>}

      {results !== null && (
        <ul>
          {results.map((result) => (
            <li key={result.id}>
              <a href={result.url}>{result.title}</a>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function isSearchResult(value: unknown): value is SearchResult {
  if (typeof value !== 'object' || value === null) {
    return false;
  }

  return (
    'id' in value &&
    typeof value.id === 'string' &&
    'title' in value &&
    typeof value.title === 'string' &&
    'url' in value &&
    typeof value.url === 'string'
  );
}
