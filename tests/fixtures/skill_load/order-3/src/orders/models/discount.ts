export type PercentDiscount = {
  kind: 'percent';
  percent: number;
};

export type FixedDiscount = {
  kind: 'fixed';
  amountCents: number;
};

export type Discount = PercentDiscount | FixedDiscount;
