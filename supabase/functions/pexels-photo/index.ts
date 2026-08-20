// Proxy de Pexels: la API key vive solo aquí, nunca en la app.
//
// Desplegar:  npx supabase functions deploy pexels-photo
// Secreto:    npx supabase secrets set PEXELS_API_KEY=...
//
// Devuelve { url } con la foto de mejor relación 16:9, o { url: null }.

const PEXELS_URL = 'https://api.pexels.com/v1/search';
const TARGET_RATIO = 16 / 9;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const apiKey = Deno.env.get('PEXELS_API_KEY');
  // Sin clave, las fotos son opcionales: se responde vacío en vez de fallar.
  if (!apiKey) return json({ url: null });

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'Cuerpo JSON inválido' }, 400);
  }

  const query = payload.query;
  if (typeof query !== 'string' || query.trim().length === 0) {
    return json({ error: 'Falta el campo "query"' }, 400);
  }

  const uri = new URL(PEXELS_URL);
  uri.searchParams.set('query', query.slice(0, 200));
  uri.searchParams.set('per_page', '3');
  uri.searchParams.set('orientation', 'landscape');
  uri.searchParams.set('size', 'medium');

  let upstream: Response;
  try {
    upstream = await fetch(uri, {
      headers: { Authorization: apiKey },
      signal: AbortSignal.timeout(15_000),
    });
  } catch {
    return json({ url: null });
  }

  if (!upstream.ok) return json({ url: null });

  let data: { photos?: Array<Record<string, unknown>> };
  try {
    data = await upstream.json();
  } catch {
    return json({ url: null });
  }

  const photos = data.photos;
  if (!Array.isArray(photos) || photos.length === 0) return json({ url: null });

  // Elegir la foto cuya relación ancho/alto se acerque más a 16:9.
  let best: Record<string, unknown> | null = null;
  let bestScore = Infinity;

  for (const p of photos) {
    const w = typeof p.width === 'number' ? p.width : null;
    const h = typeof p.height === 'number' ? p.height : null;
    // Sin dimensiones fiables no se puede puntuar: se deja como último recurso.
    const score = w && h ? Math.abs(w / h - TARGET_RATIO) : Infinity;
    if (score < bestScore) {
      bestScore = score;
      best = p;
    }
  }

  best ??= photos[0];
  const src = best.src as Record<string, unknown> | undefined;
  const url = typeof src?.medium === 'string' ? src.medium : null;

  return json({ url });
});
