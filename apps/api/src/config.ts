import path from 'node:path';
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development','test','production']).default('development'),
  FAROOQDRIVE_DATA_DIR: z.string().default(path.resolve('.data')),
  JWT_SECRET: z.string().min(32),
  APP_ENCRYPTION_KEY: z.string().min(40),
  GOOGLE_CLIENT_ID: z.string().optional(),
  GOOGLE_CLIENT_SECRET: z.string().optional()
});

let cached: z.infer<typeof schema> | null = null;
export function env() {
  if (!cached) cached = schema.parse(process.env);
  return cached;
}
export function resetEnvForTests() { cached = null; }
