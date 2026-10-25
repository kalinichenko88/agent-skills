import { useEffect, useState } from 'react';

import { fetchProducts } from './fetch-products';
import { FilterPanel } from './filter-panel/filter-panel';
import type { Product } from './models/product';
import { emptyProductFilters, type ProductFilters } from './models/product-filters';
import { ProductsGrid } from './products-grid';

type ProductsState =
  | { status: 'loading' }
  | { status: 'failed'; error: Error }
  | { status: 'done'; products: Product[] };

export function ProductsPage() {
  const [state, setState] = useState<ProductsState>({ status: 'loading' });
  const [filters, setFilters] = useState<ProductFilters>(emptyProductFilters);

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

        setState({
          status: 'failed',
          error: error instanceof Error ? error : new Error(String(error)),
        });
      });

    return () => {
      controller.abort();
    };
  }, []);

  const isLoading = state.status === 'loading';
  const isFailed = state.status === 'failed';

  if (isLoading) {
    return <p>Loading products…</p>;
  }

  if (isFailed) {
    return <p role="alert">Could not load products: {state.error.message}</p>;
  }

  return (
    <div>
      <FilterPanel onApply={setFilters} />
      <ProductsGrid products={state.products} filters={filters} />
    </div>
  );
}
