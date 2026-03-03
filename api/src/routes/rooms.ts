import { Hono } from 'hono';
import { getDb } from '../db';
import { jwtMiddleware } from '../auth';
import type { Env } from '../types';

type Variables = { userId: string; userEmail: string };

const rooms = new Hono<{ Bindings: Env; Variables: Variables }>();

rooms.use('*', jwtMiddleware);

rooms.get('/', async (c) => {
  const db = getDb(c.env);
  const userId = c.get('userId');
  const result = await db.execute({
    sql: 'SELECT id, name, code FROM rooms WHERE user_id = ? ORDER BY name',
    args: [userId],
  });
  return c.json(result.rows);
});

rooms.post('/', async (c) => {
  const { name, code } = await c.req.json<{ name: string; code: string }>();
  if (!name || !code) return c.json({ error: 'Name and code required' }, 400);

  const db = getDb(c.env);
  const userId = c.get('userId');
  const id = crypto.randomUUID();

  await db.execute({
    sql: 'INSERT INTO rooms (id, user_id, name, code) VALUES (?, ?, ?, ?)',
    args: [id, userId, name, code.toUpperCase()],
  });

  return c.json({ id, user_id: userId, name, code: code.toUpperCase() }, 201);
});

rooms.delete('/:id', async (c) => {
  const db = getDb(c.env);
  const userId = c.get('userId');
  const roomId = c.req.param('id');

  // Verify ownership
  const check = await db.execute({
    sql: 'SELECT id FROM rooms WHERE id = ? AND user_id = ?',
    args: [roomId, userId],
  });
  if (check.rows.length === 0) return c.json({ error: 'Not found' }, 404);

  // Delete items in totes belonging to this room
  await db.execute({
    sql: 'DELETE FROM items WHERE tote_id IN (SELECT id FROM totes WHERE room_id = ?)',
    args: [roomId],
  });
  // Delete totes in this room
  await db.execute({
    sql: 'DELETE FROM totes WHERE room_id = ?',
    args: [roomId],
  });
  // Delete the room
  await db.execute({
    sql: 'DELETE FROM rooms WHERE id = ?',
    args: [roomId],
  });

  return c.json({ deleted: true });
});

export default rooms;
