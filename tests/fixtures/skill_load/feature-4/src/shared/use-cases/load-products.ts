export async function loadProducts(signal: AbortSignal): Promise<unknown> {
  const response = await fetch('/api/products', { signal });

  return response.json();
}
