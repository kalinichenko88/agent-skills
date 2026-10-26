import { useEffect, useState } from 'react';

import { fetchProducts } from './fetch-products';
import type { Product } from './models/product';

export function useProducts(): ProductsState {
  const [state, setState] = useState<ProductsState>({ status: 'loading' });

  useEffect(() => {
    const controller = new AbortController();

    fetchProducts(controller.signal)
      .then((products) => {
        setState({ status: 'done', products });
      })
      .catch((error: unknown) => {
        if (controller.signal.aborted) {
          return;
        }

        setState({ status: 'failed', error: toError(error) });
      });

    return () => {
      controller.abort();
    };
  }, []);

  return state;
}

type ProductsState =
  | { status: 'loading' }
  | { status: 'failed'; error: Error }
  | { status: 'done'; products: Product[] };

function toError(error: unknown): Error {
  return error instanceof Error ? error : new Error(String(error));
}
