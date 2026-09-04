export const jsonHeaders = (origin: string) => ({
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store, max-age=0',
  'Pragma': 'no-cache',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'Access-Control-Allow-Origin': origin,
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-request-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '600',
  'Vary': 'Origin',
});

export function allowedOrigin(req: Request): string {
  const origin = req.headers.get('origin') || '';
  const configured = (Deno.env.get('SWE_ALLOWED_ORIGINS') || '')
    .split(',').map(x => x.trim()).filter(Boolean);
  if (!configured.length) throw new Error('SECURITY_CONFIG_MISSING');
  if (!origin || !configured.includes(origin)) throw new Error('ORIGIN_NOT_ALLOWED');
  return origin;
}

export function requirePost(req: Request) {
  if (req.method !== 'POST') throw new Error('METHOD_NOT_ALLOWED');
  const len = Number(req.headers.get('content-length') || '0');
  if (len > 16384) throw new Error('PAYLOAD_TOO_LARGE');
}

export function bearer(req: Request): string {
  const auth = req.headers.get('authorization') || '';
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (!m?.[1]) throw new Error('AUTH_REQUIRED');
  return m[1];
}

export function requestId(req: Request): string {
  const v = (req.headers.get('x-request-id') || '').trim();
  return /^[a-zA-Z0-9._:-]{8,128}$/.test(v) ? v : crypto.randomUUID();
}

export function safeErrorMessage(err: unknown): string {
  const code = err instanceof Error ? err.message : String(err);
  const friendly: Record<string,string> = {
    AUTH_REQUIRED:'Connexion requise', ORIGIN_NOT_ALLOWED:'Origine non autorisée',
    METHOD_NOT_ALLOWED:'Méthode non autorisée', PAYLOAD_TOO_LARGE:'Requête trop volumineuse',
    SECURITY_CONFIG_MISSING:'Configuration de sécurité serveur incomplète', RATE_LIMIT:'Trop de tentatives. Réessaie plus tard.'
  };
  return friendly[code] || 'Opération impossible';
}
