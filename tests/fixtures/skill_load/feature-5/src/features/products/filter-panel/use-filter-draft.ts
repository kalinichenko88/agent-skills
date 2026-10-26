import { useEffect, useState } from 'react';

import type { ProductFilters } from '../models/product-filters';

export function useFilterDraft(
  initialFilters: ProductFilters,
  onApply: (filters: ProductFilters) => void,
) {
  const [draft, setDraft] = useState<ProductFilters>(initialFilters);

  useEffect(() => {
    const timer = setTimeout(() => {
      onApply(draft);
    }, FILTER_DEBOUNCE_MS);

    return () => {
      clearTimeout(timer);
    };
  }, [draft, onApply]);

  function updateDraft(patch: Partial<ProductFilters>) {
    setDraft((previous) => {
      return { ...previous, ...patch };
    });
  }

  return { draft, updateDraft };
}

const FILTER_DEBOUNCE_MS = 300;
