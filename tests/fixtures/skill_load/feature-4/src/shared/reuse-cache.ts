export function reuseCache<T>(cache: Map<string, T>, key: string, load: () => T): T {
  const cached = cache.get(key);

  if (cached !== undefined) {
    return cached;
  }

  const value = load();
  cache.set(key, value);

  return value;
}
