// An order placed by a customer, with its lines.

import type { Customer } from './customer';
import type { OrderLine } from './order-line';

export type Order = {
  id: string;
  customer: Customer;
  lines: OrderLine[];
};
