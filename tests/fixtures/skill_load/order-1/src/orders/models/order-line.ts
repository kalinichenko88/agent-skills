// One line of an order: a product, how many, and its unit price in cents.

export type OrderLine = {
  productId: string;
  quantity: number;
  unitPriceCents: number;
};
