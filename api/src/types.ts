export interface Env {
  JWT_SECRET: string;
  TURSO_URL: string;
  TURSO_AUTH_TOKEN: string;
  RESEND_API_KEY: string;
  RESEND_FROM?: string; // e.g. "Storetrak <noreply@yourdomain.com>"
}

export interface User {
  id: string;
  email: string;
  password_hash: string;
  created_at: string;
}

export interface Room {
  id: string;
  user_id: string;
  name: string;
  code: string;
}

export interface Tote {
  id: string;
  room_id: string | null;
  name: string | null;
  shelf: string | null;
}

export interface Item {
  id: string;
  user_id: string;
  tote_id: string | null;
  name: string;
  category: string;
  qty: number;
  value: number | null;
  make: string | null;
  model: string | null;
  year: string | null;
  serial: string | null;
  notes: string | null;
  image_url: string | null;
}

export interface JWTPayload {
  sub: string;
  email: string;
  iat: number;
  exp: number;
}
