// An order placed by a customer, with its lines and the customer's discount.

export type Discount = PercentDiscount | FixedDiscount;

type PercentDiscount = {
  kind: 'percent';
  percent: number;
};

type FixedDiscount = {
  kind: 'fixed';
  amountCents: number;
};

export type Customer = {
  id: string;
  name: string;
  discount: Discount;
};

export type OrderLine = {
  productId: string;
  quantity: number;
  unitPriceCents: number;
};

export type Order = {
  id: string;
  customer: Customer;
  lines: OrderLine[];
};
