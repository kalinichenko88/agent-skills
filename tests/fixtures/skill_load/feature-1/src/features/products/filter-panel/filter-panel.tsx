import type { ProductFilters } from '../models/product-filters';
import { useFilterDraft } from './use-filter-draft';

type FilterPanelProps = {
  onApply: (filters: ProductFilters) => void;
};

export function FilterPanel({ onApply }: FilterPanelProps) {
  const [draft, setDraft] = useFilterDraft(onApply);

  const updateFilter = (key: keyof ProductFilters, value: string) => {
    setDraft((current) => {
      return { ...current, [key]: value };
    });
  };

  return (
    <fieldset>
      <legend>Filters</legend>
      <label>
        Name
        <input
          type="text"
          value={draft.name}
          onChange={(event) => {
            updateFilter('name', event.target.value);
          }}
        />
      </label>
      <label>
        Category
        <input
          type="text"
          value={draft.category}
          onChange={(event) => {
            updateFilter('category', event.target.value);
          }}
        />
      </label>
    </fieldset>
  );
}
