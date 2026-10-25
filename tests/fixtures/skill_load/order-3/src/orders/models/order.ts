// An order placed by a customer, with its lines.

import type { Customer } from './customer';

export type Order = {
  id: string;
  customer: Customer;
  lines: OrderLine[];
};

export type OrderLine = {
  productId: string;
  quantity: number;
  unitPriceCents: number;
};
