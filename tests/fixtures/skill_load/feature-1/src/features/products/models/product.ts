import type { z } from 'zod';

import type { productSchema } from '../schemas/product';

export type Product = z.infer<typeof productSchema>;
