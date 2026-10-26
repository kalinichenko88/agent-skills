import { useState } from 'react';

import { FilterPanel } from './filter-panel/filter-panel';
import { filterProducts } from './filter-products';
import type { ProductFilters } from './models/product-filters';
import { ProductsGrid } from './products-grid';
import { useProducts } from './use-products';

export function ProductsPage() {
  const [applied, setApplied] = useState<ProductFilters>(EMPTY_FILTERS);
  const state = useProducts();

  const visibleProducts = state.status === 'done' ? filterProducts(state.products, applied) : null;

  return (
    <main>
      <FilterPanel initialFilters={EMPTY_FILTERS} onApply={setApplied} />
      {state.status === 'loading' ? <p>Loading products…</p> : null}
      {state.status === 'failed' ? <p role="alert">Products could not be loaded.</p> : null}
      {visibleProducts !== null ? <ProductsGrid products={visibleProducts} /> : null}
    </main>
  );
}

const EMPTY_FILTERS: ProductFilters = { name: '', category: '', maxPrice: '' };
