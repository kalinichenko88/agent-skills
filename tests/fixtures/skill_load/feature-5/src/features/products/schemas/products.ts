import { z } from 'zod';

import { productSchema } from './product';

export const productsSchema = z.array(productSchema);
