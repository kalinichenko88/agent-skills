// A customer who places orders, with the discount they get.

import type { Discount } from './discount';

export type Customer = {
  id: string;
  name: string;
  discount: Discount;
};
