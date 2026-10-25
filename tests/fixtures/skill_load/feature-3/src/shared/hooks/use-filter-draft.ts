import { useEffect, useState, type Dispatch, type SetStateAction } from 'react';

import { emptyProductFilters, type ProductFilters } from '../../features/products/models/product-filters';

export function useFilterDraft(
  onApply: (filters: ProductFilters) => void,
): [ProductFilters, Dispatch<SetStateAction<ProductFilters>>] {
  const [draft, setDraft] = useState<ProductFilters>(emptyProductFilters);

  useEffect(() => {
    const timer = setTimeout(() => {
      onApply(draft);
    }, FILTER_APPLY_DELAY_MS);

    return () => {
      clearTimeout(timer);
    };
  }, [draft, onApply]);

  return [draft, setDraft];
}

const FILTER_APPLY_DELAY_MS = 300;
