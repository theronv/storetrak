import { Hono } from 'hono';
import { getDb } from '../db';
import { hashPassword, verifyPassword, signJWT } from '../auth';
import type { Env, User } from '../types';

const auth = new Hono<{ Bindings: Env }>();

auth.post('/register', async (c) => {
  const { email, password } = await c.req.json<{ email: string; password: string }>();
  if (!email || !password) return c.json({ error: 'Email and password required' }, 400);
  if (password.length < 8) return c.json({ error: 'Password must be at least 8 characters' }, 400);

  const db = getDb(c.env);

  // Check if email already exists
  const existing = await db.execute({
    sql: 'SELECT id FROM users WHERE email = ?',
    args: [email.toLowerCase()],
  });
  if (existing.rows.length > 0) return c.json({ error: 'Email already registered' }, 409);

  const id = crypto.randomUUID();
  const password_hash = await hashPassword(password);

  await db.execute({
    sql: 'INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)',
    args: [id, email.toLowerCase(), password_hash],
  });

  const now = Math.floor(Date.now() / 1000);
  const token = await signJWT(
    { sub: id, email: email.toLowerCase(), iat: now, exp: now + 7 * 24 * 60 * 60 },
    c.env.JWT_SECRET
  );

  return c.json({ token, user: { id, email: email.toLowerCase() } }, 201);
});

auth.post('/login', async (c) => {
  const { email, password } = await c.req.json<{ email: string; password: string }>();
  if (!email || !password) return c.json({ error: 'Email and password required' }, 400);

  const db = getDb(c.env);
  const result = await db.execute({
    sql: 'SELECT id, email, password_hash FROM users WHERE email = ?',
    args: [email.toLowerCase()],
  });

  if (result.rows.length === 0) return c.json({ error: 'Invalid credentials' }, 401);

  const user = result.rows[0] as unknown as User;
  const valid = await verifyPassword(password, user.password_hash);
  if (!valid) return c.json({ error: 'Invalid credentials' }, 401);

  const now = Math.floor(Date.now() / 1000);
  const token = await signJWT(
    { sub: user.id, email: user.email, iat: now, exp: now + 7 * 24 * 60 * 60 },
    c.env.JWT_SECRET
  );

  return c.json({ token, user: { id: user.id, email: user.email } });
});

export default auth;
