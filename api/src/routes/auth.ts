import { Hono } from 'hono';
import { getDb } from '../db';
import { hashPassword, verifyPassword, signJWT, jwtMiddleware } from '../auth';
import type { Env, User } from '../types';

type Variables = { userId: string; userEmail: string };
const auth = new Hono<{ Bindings: Env; Variables: Variables }>();

function randomHex(bytes: number): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(bytes)))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

async function sendResetEmail(env: Env, to: string, code: string): Promise<void> {
  const from = env.RESEND_FROM ?? 'Storetrak <noreply@storetrak.app>';
  await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${env.RESEND_API_KEY}`,
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject: 'Storetrak password reset code',
      text: `Your password reset code is: ${code.toUpperCase()}\n\nThis code expires in 30 minutes.\n\nIf you didn't request this, ignore this email.`,
    }),
  });
}

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

auth.post('/forgot-password', async (c) => {
  const { email } = await c.req.json<{ email: string }>();
  if (!email) return c.json({ error: 'Email required' }, 400);

  const db = getDb(c.env);
  const result = await db.execute({
    sql: 'SELECT id FROM users WHERE email = ?',
    args: [email.toLowerCase()],
  });

  // Always respond with the same message to prevent user enumeration
  const ok = c.json({ message: 'If that email exists, a reset code was sent.' });
  if (result.rows.length === 0) return ok;

  const userId = result.rows[0].id as string;
  const token = randomHex(4); // 8-char hex code
  const exp = Math.floor(Date.now() / 1000) + 30 * 60;

  await db.execute({
    sql: 'UPDATE users SET reset_token = ?, reset_token_exp = ? WHERE id = ?',
    args: [token, exp, userId],
  });

  await sendResetEmail(c.env, email.toLowerCase(), token);
  return ok;
});

auth.post('/reset-password', async (c) => {
  const { email, token, password } = await c.req.json<{ email: string; token: string; password: string }>();
  if (!email || !token || !password) return c.json({ error: 'Email, token, and new password required' }, 400);
  if (password.length < 8) return c.json({ error: 'Password must be at least 8 characters' }, 400);

  const db = getDb(c.env);
  const result = await db.execute({
    sql: 'SELECT id, reset_token, reset_token_exp FROM users WHERE email = ?',
    args: [email.toLowerCase()],
  });

  const invalid = () => c.json({ error: 'Invalid or expired reset code' }, 400);
  if (result.rows.length === 0) return invalid();

  const row = result.rows[0];
  const now = Math.floor(Date.now() / 1000);
  if (!row.reset_token || row.reset_token !== token.toLowerCase() || (row.reset_token_exp as number) < now) {
    return invalid();
  }

  const password_hash = await hashPassword(password);
  await db.execute({
    sql: 'UPDATE users SET password_hash = ?, reset_token = NULL, reset_token_exp = NULL WHERE id = ?',
    args: [password_hash, row.id as string],
  });

  return c.json({ message: 'Password reset successfully. Please log in.' });
});

auth.post('/change-password', jwtMiddleware, async (c) => {
  const { currentPassword, newPassword } = await c.req.json<{ currentPassword: string; newPassword: string }>();
  if (!currentPassword || !newPassword) return c.json({ error: 'Current and new password required' }, 400);
  if (newPassword.length < 8) return c.json({ error: 'Password must be at least 8 characters' }, 400);

  const db = getDb(c.env);
  const result = await db.execute({
    sql: 'SELECT password_hash FROM users WHERE id = ?',
    args: [c.get('userId')],
  });

  if (result.rows.length === 0) return c.json({ error: 'User not found' }, 404);
  const valid = await verifyPassword(currentPassword, result.rows[0].password_hash as string);
  if (!valid) return c.json({ error: 'Current password is incorrect' }, 401);

  const password_hash = await hashPassword(newPassword);
  await db.execute({
    sql: 'UPDATE users SET password_hash = ? WHERE id = ?',
    args: [password_hash, c.get('userId')],
  });

  return c.json({ message: 'Password changed successfully.' });
});

export default auth;
