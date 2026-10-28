import type { Product } from './models/product';

type ProductsGridProps = {
  products: Product[];
};

export function ProductsGrid({ products }: ProductsGridProps) {
  if (products.length === 0) {
    return <p>No products match the filters.</p>;
  }

  return (
    <ul>
      {products.map((product) => {
        return (
          <li key={product.id}>
            <h3>{product.name}</h3>
            <p>{product.category}</p>
            <p>{PRICE_FORMAT.format(product.price)}</p>
          </li>
        );
      })}
    </ul>
  );
}

const PRICE_FORMAT = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });
