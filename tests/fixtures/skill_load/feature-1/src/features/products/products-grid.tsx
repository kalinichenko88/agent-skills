import type { Product } from './models/product';
import type { ProductFilters } from './models/product-filters';

type ProductsGridProps = {
  products: Product[];
  filters: ProductFilters;
};

export function ProductsGrid({ products, filters }: ProductsGridProps) {
  const visible = products.filter((product) => {
    return matchesFilters(product, filters);
  });

  const isEmpty = visible.length === 0;

  if (isEmpty) {
    return <p>No products match the filters.</p>;
  }

  return (
    <ul>
      {visible.map((product) => {
        return (
          <li key={product.id}>
            <h3>{product.name}</h3>
            <p>{product.category}</p>
            <p>{formatPrice(product.price)}</p>
          </li>
        );
      })}
    </ul>
  );
}

function matchesFilters(product: Product, filters: ProductFilters): boolean {
  const nameQuery = filters.name.trim().toLowerCase();
  const categoryQuery = filters.category.trim().toLowerCase();

  const matchesName = product.name.toLowerCase().includes(nameQuery);
  const matchesCategory = categoryQuery === '' || product.category.toLowerCase() === categoryQuery;

  return matchesName && matchesCategory;
}

// Assumes prices are in US dollars. Change the currency if the API says otherwise.
const priceFormat = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

function formatPrice(price: number): string {
  return priceFormat.format(price);
}
