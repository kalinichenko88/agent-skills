const BASE = '/api';

export async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = { ...init.headers, Authorization: `Bearer ${token()}` };
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(BASE + path, { ...init, headers });
    if (res.ok) return res.json() as Promise<T>;
    if (res.status < 500 || attempt === 2) throw new Error(`${res.status} ${path}`);
  }
}

function token(): string {
  return localStorage.getItem('token') ?? '';
}
