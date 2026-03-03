import { createClient, type Client } from '@libsql/client/web';
import type { Env } from './types';

let client: Client | null = null;

export function getDb(env: Env): Client {
  if (!client) {
    client = createClient({
      url: env.TURSO_URL,
      authToken: env.TURSO_AUTH_TOKEN,
    });
  }
  return client;
}

// Reset client between requests in case env changes (e.g., during testing)
export function resetDb(): void {
  client = null;
}
