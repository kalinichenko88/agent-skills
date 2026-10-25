// Returns the order total in cents, after the customer discount.

import type { Discount } from './models/discount';
import type { Order } from './models/order';

export function orderTotalCents(order: Order): number {
  const subtotalCents = order.lines.reduce((sum, line) => {
    return sum + line.quantity * line.unitPriceCents;
  }, 0);

  const discountCents = discountAmountCents(order.customer.discount, subtotalCents);

  return Math.max(0, subtotalCents - discountCents);
}

function discountAmountCents(discount: Discount, subtotalCents: number): number {
  if (discount.kind === 'percent') {
    return Math.round((subtotalCents * discount.percent) / 100);
  }

  return discount.amountCents;
}
