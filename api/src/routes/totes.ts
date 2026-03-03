import { Hono } from 'hono';
import { getDb } from '../db';
import { jwtMiddleware } from '../auth';
import type { Env } from '../types';

type Variables = { userId: string; userEmail: string };

const totes = new Hono<{ Bindings: Env; Variables: Variables }>();

totes.use('*', jwtMiddleware);

totes.get('/', async (c) => {
  const db = getDb(c.env);
  const userId = c.get('userId');
  // Return totes that belong to this user's rooms (or have no room)
  const result = await db.execute({
    sql: `SELECT t.id, t.room_id, t.name, t.shelf
          FROM totes t
          WHERE t.room_id IN (SELECT id FROM rooms WHERE user_id = ?)
          ORDER BY t.id`,
    args: [userId],
  });
  return c.json(result.rows);
});

totes.post('/', async (c) => {
  const { id, room_id, name, shelf } = await c.req.json<{
    id?: string;
    room_id: string;
    name?: string;
    shelf?: string;
  }>();
  if (!room_id) return c.json({ error: 'room_id required' }, 400);

  const db = getDb(c.env);
  const userId = c.get('userId');

  // Verify user owns the room
  const roomCheck = await db.execute({
    sql: 'SELECT id FROM rooms WHERE id = ? AND user_id = ?',
    args: [room_id, userId],
  });
  if (roomCheck.rows.length === 0) return c.json({ error: 'Room not found' }, 404);

  const toteId = id || crypto.randomUUID();

  await db.execute({
    sql: 'INSERT INTO totes (id, room_id, name, shelf) VALUES (?, ?, ?, ?)',
    args: [toteId, room_id, name || null, shelf || null],
  });

  return c.json({ id: toteId, room_id, name: name || null, shelf: shelf || null }, 201);
});

totes.patch('/:id', async (c) => {
  const db = getDb(c.env);
  const userId = c.get('userId');
  const toteId = c.req.param('id');

  // Verify user owns this tote (via its room)
  const check = await db.execute({
    sql: `SELECT t.id FROM totes t
          JOIN rooms r ON t.room_id = r.id
          WHERE t.id = ? AND r.user_id = ?`,
    args: [toteId, userId],
  });
  if (check.rows.length === 0) return c.json({ error: 'Not found' }, 404);

  const updates = await c.req.json<{ name?: string; shelf?: string; room_id?: string }>();

  if (updates.room_id) {
    // Verify user owns the target room too
    const roomCheck = await db.execute({
      sql: 'SELECT id FROM rooms WHERE id = ? AND user_id = ?',
      args: [updates.room_id, userId],
    });
    if (roomCheck.rows.length === 0) return c.json({ error: 'Target room not found' }, 404);
  }

  const fields: string[] = [];
  const args: (string | null)[] = [];

  if ('name' in updates) { fields.push('name = ?'); args.push(updates.name || null); }
  if ('shelf' in updates) { fields.push('shelf = ?'); args.push(updates.shelf || null); }
  if ('room_id' in updates) { fields.push('room_id = ?'); args.push(updates.room_id || null); }

  if (fields.length === 0) return c.json({ error: 'No fields to update' }, 400);

  args.push(toteId);
  await db.execute({
    sql: `UPDATE totes SET ${fields.join(', ')} WHERE id = ?`,
    args,
  });

  const result = await db.execute({
    sql: 'SELECT id, room_id, name, shelf FROM totes WHERE id = ?',
    args: [toteId],
  });
  return c.json(result.rows[0]);
});

totes.delete('/:id', async (c) => {
  const db = getDb(c.env);
  const userId = c.get('userId');
  const toteId = c.req.param('id');

  // Verify ownership
  const check = await db.execute({
    sql: `SELECT t.id FROM totes t
          JOIN rooms r ON t.room_id = r.id
          WHERE t.id = ? AND r.user_id = ?`,
    args: [toteId, userId],
  });
  if (check.rows.length === 0) return c.json({ error: 'Not found' }, 404);

  // Delete items in this tote first
  await db.execute({
    sql: 'DELETE FROM items WHERE tote_id = ?',
    args: [toteId],
  });
  await db.execute({
    sql: 'DELETE FROM totes WHERE id = ?',
    args: [toteId],
  });

  return c.json({ deleted: true });
});

export default totes;
