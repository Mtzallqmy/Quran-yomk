import { Elysia } from 'elysia'

const upstream = (process.env.TARTEEL_UPSTREAM_API ??
  'https://qkroecnecdxghcqvvoxn.supabase.co/functions/v1/tarteel-api').replace(/\/$/, '')
const MAX_RESPONSE_BYTES = 5 * 1024 * 1024
const UPSTREAM_TIMEOUT_MS = 12_000
const apiKey = () => process.env.TARTEEL_API_KEY ?? ''

function safeResponseHeaders(headers: Headers): Headers {
  const result = new Headers({ 'content-type': 'application/json; charset=utf-8' })
  for (const name of ['content-type', 'cache-control', 'x-request-id']) {
    const value = headers.get(name)
    if (value) result.set(name, value)
  }
  result.set('x-tarteel-api-adapter', 'elysia-proxy')
  return result
}

export function canonicalUpstreamUrl(request: Request): URL {
  const incoming = new URL(request.url)
  const marker = '/v1/'
  const index = incoming.pathname.indexOf(marker)
  const path = index >= 0 ? incoming.pathname.slice(index + marker.length) : ''
  if (!path || path.includes('..') || path.includes('\\')) throw new Error('INVALID_PROXY_PATH')
  const target = new URL(`${upstream}/${path}`)
  target.search = incoming.search
  return target
}

export async function proxyPublicRequest(request: Request): Promise<Response> {
  const key = apiKey()
  if (!key) {
    return Response.json(
      { error: { code: 'SERVER_NOT_CONFIGURED', message: 'Canonical public API key is not configured' } },
      { status: 503, headers: { 'cache-control': 'no-store' } }
    )
  }

  let target: URL
  try {
    target = canonicalUpstreamUrl(request)
  } catch {
    return Response.json(
      { error: { code: 'VALIDATION_ERROR', message: 'Invalid public API path' } },
      { status: 422, headers: { 'cache-control': 'no-store' } }
    )
  }

  const requestId = request.headers.get('x-request-id')
  const headers: Record<string, string> = { apikey: key, accept: 'application/json' }
  if (requestId) headers['x-request-id'] = requestId

  try {
    const response = await fetch(target, {
      method: 'GET',
      headers,
      redirect: 'error',
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS)
    })
    const declared = Number(response.headers.get('content-length') ?? 0)
    if (Number.isFinite(declared) && declared > MAX_RESPONSE_BYTES) throw new Error('UPSTREAM_RESPONSE_TOO_LARGE')
    const bytes = new Uint8Array(await response.arrayBuffer())
    if (bytes.byteLength > MAX_RESPONSE_BYTES) throw new Error('UPSTREAM_RESPONSE_TOO_LARGE')
    return new Response(bytes, { status: response.status, headers: safeResponseHeaders(response.headers) })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    const code = message.includes('TOO_LARGE') ? 'UPSTREAM_RESPONSE_TOO_LARGE' : 'UPSTREAM_UNAVAILABLE'
    const status = code === 'UPSTREAM_RESPONSE_TOO_LARGE' ? 502 : 503
    return Response.json(
      { error: { code, message: 'Canonical public API is unavailable' } },
      { status, headers: { 'cache-control': 'no-store', 'x-tarteel-api-adapter': 'elysia-proxy' } }
    )
  }
}

export const app = new Elysia({ name: 'tarteel-api-elysia' })
  .get('/health', () => ({
    ok: true,
    service: 'tarteel-api-elysia',
    mode: 'canonical-upstream-proxy',
    upstream: new URL(upstream).hostname,
    configured: Boolean(apiKey())
  }))
  .get('/v1/*', ({ request }) => proxyPublicRequest(request))

if (import.meta.main) {
  app.listen(Number(process.env.PORT ?? 3000))
  console.log(`Tarteel Elysia API listening on ${app.server?.hostname}:${app.server?.port}`)
}
