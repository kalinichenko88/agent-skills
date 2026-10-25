import { z } from 'zod';

export async function fetchProducts(signal: AbortSignal): Promise<Product[]> {
  const response = await fetch('/api/products', { signal });

  if (!response.ok) {
    throw new Error(`GET /api/products failed with status ${response.status}`);
  }

  const data: unknown = await response.json();

  return z.array(productSchema).parse(data);
}

const productSchema = z.object({
  id: z.string(),
  name: z.string(),
  price: z.number(),
  category: z.string(),
});

type Product = z.infer<typeof productSchema>;
