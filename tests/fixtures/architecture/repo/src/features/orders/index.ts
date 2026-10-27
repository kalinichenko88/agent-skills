import { request } from '../../api/client';
import { formatPrice } from '../../lib/money';

export type Order = { id: string; totalCents: number };

export function listOrders(): Promise<Order[]> {
  return request<Order[]>('/orders');
}

export function getOrder(id: string): Promise<Order> {
  return request<Order>(`/orders/${id}`);
}

export function orderLabel(order: Order): string {
  return `#${order.id}: ${formatPrice(order.totalCents)}`;
}
