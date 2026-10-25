// Returns a text summary of an order: one row per line, then the total.

import type { Order } from './order';
import { orderTotalCents } from './order-total';

const money = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

function formatCents(cents: number): string {
  return money.format(cents / 100);
}

export function orderSummary(order: Order): string {
  const rows = order.lines.map((line) => {
    return `${line.productId} × ${line.quantity}: ${formatCents(line.quantity * line.unitPriceCents)}`;
  });

  const totalRow = `Total: ${formatCents(orderTotalCents(order))}`;

  return [...rows, totalRow].join('\n');
}
