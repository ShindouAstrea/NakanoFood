// Proxy de OpenAI: la API key vive solo aquí, nunca en la app.
//
// Desplegar:  npx supabase functions deploy openai-complete
// Secreto:    npx supabase secrets set OPENAI_API_KEY=sk-...
//
// La app llama a esta función con supabase.functions.invoke('openai-complete').

const MODEL = 'gpt-4o-mini';
const MAX_TOKENS = 3000;
const OPENAI_URL = 'https://api.openai.com/v1/chat/completions';

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

  const apiKey = Deno.env.get('OPENAI_API_KEY');
  if (!apiKey) {
    // Falta el secreto en el proyecto, no es culpa del cliente.
    return json({ error: 'OPENAI_API_KEY no está configurada en Supabase' }, 503);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'Cuerpo JSON inválido' }, 400);
  }

  const prompt = payload.prompt;
  if (typeof prompt !== 'string' || prompt.trim().length === 0) {
    return json({ error: 'Falta el campo "prompt"' }, 400);
  }
  // Techo defensivo: evita que un cliente manipulado dispare el gasto.
  if (prompt.length > 8000) {
    return json({ error: 'El prompt excede el límite de 8000 caracteres' }, 413);
  }

  const systemPrompt =
    typeof payload.systemPrompt === 'string' && payload.systemPrompt.length > 0
      ? payload.systemPrompt
      : 'Eres un asistente experto. Siempre responde en JSON válido.';

  const temperature =
    typeof payload.temperature === 'number' &&
    payload.temperature >= 0 &&
    payload.temperature <= 2
      ? payload.temperature
      : 0.8;

  let upstream: Response;
  try {
    upstream = await fetch(OPENAI_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: prompt },
        ],
        response_format: { type: 'json_object' },
        temperature,
        max_tokens: MAX_TOKENS,
      }),
      signal: AbortSignal.timeout(45_000),
    });
  } catch (e) {
    const timedOut = e instanceof DOMException && e.name === 'TimeoutError';
    return json(
      { error: timedOut ? 'OpenAI tardó demasiado en responder' : 'No se pudo contactar a OpenAI' },
      504,
    );
  }

  const raw = await upstream.text();

  if (!upstream.ok) {
    // OpenAI devuelve HTML en algunos errores de borde; no asumir JSON.
    let message = raw.slice(0, 300);
    try {
      message = JSON.parse(raw)?.error?.message ?? message;
    } catch { /* se queda el texto crudo recortado */ }
    return json({ error: `OpenAI ${upstream.status}: ${message}` }, 502);
  }

  // Validar la forma antes de indexar: 'choices' puede venir vacío y
  // 'content' nulo cuando el modelo rechaza la petición.
  let data: { choices?: Array<{ message?: { content?: unknown } }> };
  try {
    data = JSON.parse(raw);
  } catch {
    return json({ error: 'OpenAI devolvió una respuesta ilegible' }, 502);
  }

  const content = data.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || content.length === 0) {
    return json({ error: 'OpenAI no devolvió contenido' }, 502);
  }

  return json({ content });
});
