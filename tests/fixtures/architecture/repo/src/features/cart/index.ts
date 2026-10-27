import { request } from '../../api/client';
import { formatPrice } from '../../lib/money';

export type CartItem = { productId: string; name: string; unitPriceCents: number; quantity: number };
export type Cart = { items: CartItem[] };

export function emptyCart(): Cart {
  return { items: [] };
}

export function addItem(cart: Cart, item: CartItem): Cart {
  const existing = cart.items.find((i) => i.productId === item.productId);
  if (!existing) return { items: [...cart.items, item] };
  return {
    items: cart.items.map((i) =>
      i.productId === item.productId ? { ...i, quantity: i.quantity + item.quantity } : i,
    ),
  };
}

export function removeItem(cart: Cart, productId: string): Cart {
  return { items: cart.items.filter((i) => i.productId !== productId) };
}

export function lineTotalCents(item: CartItem): number {
  return item.unitPriceCents * item.quantity;
}

export function totalCents(cart: Cart): number {
  return cart.items.reduce((sum, item) => sum + lineTotalCents(item), 0);
}

export function cartSummary(cart: Cart): string {
  const lines = cart.items.map((i) => `${i.name} x${i.quantity}: ${formatPrice(lineTotalCents(i))}`);
  return [...lines, `Total: ${formatPrice(totalCents(cart))}`].join('\n');
}

export function loadCart(): Promise<Cart> {
  return request<Cart>('/cart');
}

export function saveCart(cart: Cart): Promise<Cart> {
  return request<Cart>('/cart', { method: 'PUT', body: JSON.stringify(cart) });
}
