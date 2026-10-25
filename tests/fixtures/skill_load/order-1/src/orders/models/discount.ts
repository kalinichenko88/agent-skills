// Customer discount: a percent of the subtotal, or a fixed amount in cents.

export type Discount = PercentDiscount | FixedDiscount;

type PercentDiscount = {
  kind: 'percent';
  percent: number;
};

type FixedDiscount = {
  kind: 'fixed';
  amountCents: number;
};
