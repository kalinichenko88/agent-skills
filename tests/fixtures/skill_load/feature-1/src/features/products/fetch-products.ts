import { z } from 'zod';

import type { Product } from './models/product';
import { productSchema } from './schemas/product';

export async function fetchProducts(signal: AbortSignal): Promise<Product[]> {
  const response = await fetch('/api/products', { signal });

  if (!response.ok) {
    throw new Error(`GET /api/products failed with status ${response.status}`);
  }

  const data: unknown = await response.json();

  return z.array(productSchema).parse(data);
}
