import { Hono } from 'hono';
import { cors } from 'hono/cors';
import type { Env } from './types';
import authRoutes from './routes/auth';
import roomRoutes from './routes/rooms';
import toteRoutes from './routes/totes';
import itemRoutes from './routes/items';

const app = new Hono<{ Bindings: Env }>();

app.use('*', cors({
  origin: ['https://storetrak.pages.dev', 'https://theronv.github.io', 'http://localhost:3000', 'http://localhost:8080'],
  allowHeaders: ['Content-Type', 'Authorization'],
  allowMethods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
}));

app.get('/', (c) => c.json({ service: 'storetrak-api', version: '1.0.0' }));

app.route('/auth', authRoutes);
app.route('/rooms', roomRoutes);
app.route('/totes', toteRoutes);
app.route('/items', itemRoutes);

app.notFound((c) => c.json({ error: 'Not found' }, 404));
app.onError((err, c) => {
  console.error(err);
  return c.json({ error: 'Internal server error' }, 500);
});

export default app;
