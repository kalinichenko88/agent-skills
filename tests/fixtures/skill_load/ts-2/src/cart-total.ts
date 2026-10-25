export type CartItem = {
  id: string;
  name: string;
  unitPriceCents: number;
  quantity: number;
};

export function cartTotalCents(items: CartItem[]): number {
  return items.reduce((total, item) => {
    if (item.quantity === 0) {
      return total;
    }

    return total + item.unitPriceCents * item.quantity;
  }, 0);
}

export function itemNamesOverPrice(items: CartItem[], limitCents: number): string[] {
  return items
    .filter((item) => item.unitPriceCents > limitCents)
    .map((item) => {
      return item.name;
    });
}
