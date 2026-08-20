# Edge Functions

Estas funciones existen por una razón concreta: el `.env` de Flutter se
empaqueta **dentro del APK** como asset, así que cualquiera puede
descomprimirlo y leer lo que haya ahí. Las claves de OpenAI y Pexels ya no
viajan con la app — viven aquí, en el servidor.

| Función | Qué hace | Secreto que consume |
|---|---|---|
| `openai-complete` | Pide texto al modelo (JSON mode) para generar recetas | `OPENAI_API_KEY` |
| `pexels-photo` | Busca una foto de comida y elige la más cercana a 16:9 | `PEXELS_API_KEY` |

## Despliegue

Requiere el CLI de Supabase. Si no lo tienes instalado, `npx` funciona igual.

```bash
# 1. Vincular el proyecto (solo la primera vez).
#    El ref está en el panel: Settings → General → Reference ID
npx supabase login
npx supabase link --project-ref bermboxqhqobhawuoahk

# 2. Cargar los secretos. Usa claves NUEVAS: las anteriores estuvieron
#    dentro de APKs compilados y hay que darlas por comprometidas.
npx supabase secrets set OPENAI_API_KEY=
npx supabase secrets set PEXELS_API_KEY=

# 3. Desplegar
npx supabase functions deploy openai-complete
npx supabase functions deploy pexels-photo
```

Comprobar que quedaron arriba:

```bash
npx supabase functions list
npx supabase secrets list      # muestra los nombres, no los valores
```

## Usuarios sin cuenta

Por defecto Supabase exige un JWT válido para invocar una función. La app
ofrece "Usar sin cuenta (solo local)", y esos usuarios no tienen sesión.

Decide cuál de las dos quieres:

- **Solo usuarios con cuenta** (recomendado): déjalo como está. La IA queda
  como una razón más para registrarse, y el gasto es atribuible a alguien.
- **También sin cuenta**: despliega con `--no-verify-jwt`. Ojo: la función
  queda abierta a internet y cualquiera puede gastar tu cuota de OpenAI.

## Límite de uso

No hay ninguno todavía. Hoy un usuario con sesión puede llamar a
`openai-complete` en bucle y la factura es tuya. Cuando quieras ponerle
techo, lo habitual es una tabla `ai_usage (user_id, day, count)` con RLS y
un chequeo al principio de la función.

## Probar en local

```bash
npx supabase functions serve openai-complete --env-file supabase/.env.local
```

```bash
curl -X POST http://localhost:54321/functions/v1/openai-complete \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TU_PUBLISHABLE_KEY>" \
  -d '{"prompt":"Dame una receta de tallarines en JSON"}'
```
