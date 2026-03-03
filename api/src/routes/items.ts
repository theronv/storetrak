import { Hono } from 'hono';
import { getDb } from '../db';
import { jwtMiddleware } from '../auth';
import type { Env } from '../types';

type Variables = { userId: string; userEmail: string };

const items = new Hono<{ Bindings: Env; Variables: Variables }>();

items.use('*', jwtMiddleware);

items.get('/', async (c) => {
  const db = getDb(c.env);
  const userId = c.get('userId');
  const result = await db.execute({
    sql: 'SELECT * FROM items WHERE user_id = ? ORDER BY name',
    args: [userId],
  });
  return c.json(result.rows);
});

items.post('/', async (c) => {
  const body = await c.req.json<{
    name: string;
    tote_id?: string | null;
    category?: string;
    qty?: number;
    value?: number | null;
    make?: string | null;
    model?: string | null;
    year?: string | null;
    serial?: string | null;
    notes?: string | null;
    image_url?: string | null;
  }>();

  if (!body.name) return c.json({ error: 'Name required' }, 400);

  const db = getDb(c.env);
  const userId = c.get('userId');

  // Verify tote ownership if provided
  if (body.tote_id) {
    const toteCheck = await db.execute({
      sql: `SELECT t.id FROM totes t
            JOIN rooms r ON t.room_id = r.id
            WHERE t.id = ? AND r.user_id = ?`,
      args: [body.tote_id, userId],
    });
    if (toteCheck.rows.length === 0) return c.json({ error: 'Tote not found' }, 404);
  }

  const id = crypto.randomUUID();
  await db.execute({
    sql: `INSERT INTO items (id, user_id, tote_id, name, category, qty, value, make, model, year, serial, notes, image_url)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    args: [
      id, userId, body.tote_id || null, body.name,
      body.category || 'other', body.qty ?? 1,
      body.value ?? null, body.make ?? null, body.model ?? null,
      body.year ?? null, body.serial ?? null, body.notes ?? null,
      body.image_url ?? null,
    ],
  });

  return c.json({
    id, user_id: userId, tote_id: body.tote_id || null, name: body.name,
    category: body.category || 'other', qty: body.qty ?? 1,
    value: body.value ?? null, make: body.make ?? null, model: body.model ?? null,
    year: body.year ?? null, serial: body.serial ?? null, notes: body.notes ?? null,
    image_url: body.image_url ?? null,
  }, 201);
});

// Bulk PATCH — body: { ids: string[], tote_id: string | null }
items.patch('/', async (c) => {
  const { ids, tote_id } = await c.req.json<{ ids: string[]; tote_id: string | null }>();
  if (!Array.isArray(ids) || ids.length === 0) return c.json({ error: 'ids array required' }, 400);

  const db = getDb(c.env);
  const userId = c.get('userId');

  // Verify tote ownership if provided
  if (tote_id) {
    const toteCheck = await db.execute({
      sql: `SELECT t.id FROM totes t
            JOIN rooms r ON t.room_id = r.id
            WHERE t.id = ? AND r.user_id = ?`,
      args: [tote_id, userId],
    });
    if (toteCheck.rows.length === 0) return c.json({ error: 'Tote not found' }, 404);
  }

  // Use placeholders for the IN clause
  const placeholders = ids.map(() => '?').join(',');
  await db.execute({
    sql: `UPDATE items SET tote_id = ? WHERE id IN (${placeholders}) AND user_id = ?`,
    args: [tote_id, ...ids, userId],
  });

  return c.json({ updated: ids.length });
});

items.patch('/:id', async (c) => {
  const db = getDb(c.env);
  const userId = c.get('userId');
  const itemId = c.req.param('id');

  const check = await db.execute({
    sql: 'SELECT id FROM items WHERE id = ? AND user_id = ?',
    args: [itemId, userId],
  });
  if (check.rows.length === 0) return c.json({ error: 'Not found' }, 404);

  const updates = await c.req.json<Record<string, unknown>>();

  // Verify tote ownership if tote_id is being set
  if (updates.tote_id) {
    const toteCheck = await db.execute({
      sql: `SELECT t.id FROM totes t
            JOIN rooms r ON t.room_id = r.id
            WHERE t.id = ? AND r.user_id = ?`,
      args: [updates.tote_id, userId],
    });
    if (toteCheck.rows.length === 0) return c.json({ error: 'Tote not found' }, 404);
  }

  const allowed = ['name', 'tote_id', 'category', 'qty', 'value', 'make', 'model', 'year', 'serial', 'notes', 'image_url'];
  const fields: string[] = [];
  const args: unknown[] = [];

  for (const key of allowed) {
    if (key in updates) {
      fields.push(`${key} = ?`);
      args.push(updates[key] ?? null);
    }
  }

  if (fields.length === 0) return c.json({ error: 'No fields to update' }, 400);

  args.push(itemId);
  await db.execute({
    sql: `UPDATE items SET ${fields.join(', ')} WHERE id = ?`,
    args: args as (string | number | null)[],
  });

  const result = await db.execute({
    sql: 'SELECT * FROM items WHERE id = ?',
    args: [itemId],
  });
  return c.json(result.rows[0]);
});

items.delete('/:id', async (c) => {
  const db = getDb(c.env);
  const userId = c.get('userId');
  const itemId = c.req.param('id');

  const check = await db.execute({
    sql: 'SELECT id FROM items WHERE id = ? AND user_id = ?',
    args: [itemId, userId],
  });
  if (check.rows.length === 0) return c.json({ error: 'Not found' }, 404);

  await db.execute({
    sql: 'DELETE FROM items WHERE id = ?',
    args: [itemId],
  });

  return c.json({ deleted: true });
});

export default items;
