/**
 * One-time migration: Supabase → Turso
 *
 * Usage:
 *   TURSO_URL=libsql://... TURSO_AUTH_TOKEN=... \
 *   SB_URL=https://xxx.supabase.co SB_KEY=sb_publishable_... \
 *   ADMIN_EMAIL=you@example.com ADMIN_PASSWORD=changeme123 \
 *   npx tsx src/migrate.ts
 */

import { createClient } from '@libsql/client';

const TURSO_URL = process.env.TURSO_URL!.trim();
const TURSO_AUTH_TOKEN = process.env.TURSO_AUTH_TOKEN!.replace(/\s/g, '');
const SB_URL = process.env.SB_URL!.trim();
const SB_KEY = process.env.SB_KEY!.trim();
const ADMIN_EMAIL = process.env.ADMIN_EMAIL!.trim();
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD!;

if (!TURSO_URL || !TURSO_AUTH_TOKEN || !SB_URL || !SB_KEY || !ADMIN_EMAIL || !ADMIN_PASSWORD) {
  console.error('Missing required environment variables');
  process.exit(1);
}

// ── Supabase fetch ──
async function sbGet(path: string): Promise<unknown[]> {
  const r = await fetch(`${SB_URL}/rest/v1/${path}`, {
    headers: { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}` },
  });
  if (!r.ok) throw new Error(`Supabase ${path}: ${r.status} ${await r.text()}`);
  return r.json() as Promise<unknown[]>;
}

// ── PBKDF2 hashing (Node.js compatible) ──
async function hashPassword(password: string): Promise<string> {
  const { createHash, randomBytes, pbkdf2Sync } = await import('crypto');
  void createHash; // not used, just for import check
  const salt = randomBytes(16);
  const hash = pbkdf2Sync(password, salt, 100_000, 32, 'sha256');
  return `${salt.toString('hex')}:${hash.toString('hex')}`;
}

async function main() {
  const db = createClient({ url: TURSO_URL, authToken: TURSO_AUTH_TOKEN });

  console.log('Fetching data from Supabase...');
  const [rooms, totes, items] = await Promise.all([
    sbGet('rooms?select=*&order=name'),
    sbGet('totes?select=*&order=id'),
    sbGet('items?select=*&order=name'),
  ]) as [
    Array<{ id: string; name: string; code: string }>,
    Array<{ id: string; room_id: string; name: string; shelf: string }>,
    Array<{ id: string; tote_id: string; name: string; category: string; qty: number; value: number; make: string; model: string; year: string; serial: string; notes: string; image_url: string }>,
  ];

  console.log(`Found: ${rooms.length} rooms, ${totes.length} totes, ${items.length} items`);

  // Create schema
  console.log('Creating schema...');
  await db.executeMultiple(`
    CREATE TABLE IF NOT EXISTS users (
      id   TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    );
    CREATE TABLE IF NOT EXISTS rooms (
      id      TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name    TEXT NOT NULL,
      code    TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS totes (
      id      TEXT PRIMARY KEY,
      room_id TEXT REFERENCES rooms(id) ON DELETE SET NULL,
      name    TEXT,
      shelf   TEXT
    );
    CREATE TABLE IF NOT EXISTS items (
      id        TEXT PRIMARY KEY,
      user_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      tote_id   TEXT REFERENCES totes(id) ON DELETE SET NULL,
      name      TEXT NOT NULL,
      category  TEXT DEFAULT 'other',
      qty       INTEGER DEFAULT 1,
      value     REAL,
      make      TEXT,
      model     TEXT,
      year      TEXT,
      serial    TEXT,
      notes     TEXT,
      image_url TEXT
    );
  `);

  // Create admin user
  const userId = crypto.randomUUID();
  const password_hash = await hashPassword(ADMIN_PASSWORD);

  console.log(`Creating user: ${ADMIN_EMAIL}`);
  await db.execute({
    sql: 'INSERT OR IGNORE INTO users (id, email, password_hash) VALUES (?, ?, ?)',
    args: [userId, ADMIN_EMAIL.toLowerCase(), password_hash],
  });

  // Check if user already exists (re-run safety)
  const existingUser = await db.execute({
    sql: 'SELECT id FROM users WHERE email = ?',
    args: [ADMIN_EMAIL.toLowerCase()],
  });
  const finalUserId = existingUser.rows[0]?.id as string ?? userId;

  // Migrate rooms
  console.log('Migrating rooms...');
  for (const room of rooms) {
    await db.execute({
      sql: 'INSERT OR IGNORE INTO rooms (id, user_id, name, code) VALUES (?, ?, ?, ?)',
      args: [room.id, finalUserId, room.name, room.code],
    });
  }

  // Migrate totes
  console.log('Migrating totes...');
  for (const tote of totes) {
    await db.execute({
      sql: 'INSERT OR IGNORE INTO totes (id, room_id, name, shelf) VALUES (?, ?, ?, ?)',
      args: [tote.id, tote.room_id || null, tote.name || null, tote.shelf || null],
    });
  }

  // Migrate items
  console.log('Migrating items...');
  let count = 0;
  for (const item of items) {
    await db.execute({
      sql: `INSERT OR IGNORE INTO items
              (id, user_id, tote_id, name, category, qty, value, make, model, year, serial, notes, image_url)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      args: [
        item.id, finalUserId, item.tote_id || null, item.name,
        item.category || 'other', item.qty ?? 1,
        item.value ?? null, item.make ?? null, item.model ?? null,
        item.year ?? null, item.serial ?? null, item.notes ?? null,
        item.image_url ?? null,
      ],
    });
    count++;
    if (count % 50 === 0) console.log(`  ...${count}/${items.length} items`);
  }

  console.log(`\nMigration complete!`);
  console.log(`  User ID: ${finalUserId}`);
  console.log(`  Email:   ${ADMIN_EMAIL}`);
  console.log(`  Rooms:   ${rooms.length}`);
  console.log(`  Totes:   ${totes.length}`);
  console.log(`  Items:   ${items.length}`);
  console.log(`\nYou can now log in to the web app with ${ADMIN_EMAIL}`);

  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
