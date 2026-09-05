import { Elysia } from 'elysia'

const upstream = (process.env.TARTEEL_UPSTREAM_API ??
  'https://qkroecnecdxghcqvvoxn.supabase.co/functions/v1/tarteel-api').replace(/\/$/, '')
const MAX_RESPONSE_BYTES = 5 * 1024 * 1024
const UPSTREAM_TIMEOUT_MS = 12_000
const apiKey = () => process.env.TARTEEL_API_KEY ?? ''

export const failureCounters = { upstream: 0, internal: 0 }
function operationId(request: Request): string {
  const id = request.headers.get('x-request-id') ?? ''
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id) ? id : crypto.randomUUID()
}
function failure(code: string, message: string, status: number, id: string): Response {
  if (status >= 500) {
    if (code.startsWith('UPSTREAM')) failureCounters.upstream++
    else failureCounters.internal++
    console.error(JSON.stringify({ event: 'API_FAILURE', code, status, request_id: id }))
  }
  return Response.json({ error: { code, message, request_id: id } }, {
    status, headers: { 'cache-control': 'no-store', 'x-request-id': id, 'x-tarteel-api-adapter': 'elysia-proxy' }
  })
}

function safeResponseHeaders(headers: Headers): Headers {
  const result = new Headers({ 'content-type': 'application/json; charset=utf-8' })
  for (const name of ['content-type', 'cache-control', 'x-request-id']) {
    const value = headers.get(name)
    if (value) result.set(name, value)
  }
  result.set('x-tarteel-api-adapter', 'elysia-proxy')
  return result
}

export async function readCanonicalResponse(response: Response, maxBytes = MAX_RESPONSE_BYTES): Promise<Uint8Array<ArrayBuffer>> {
  const reject = async (code: string): Promise<never> => {
    await response.body?.cancel().catch(() => {})
    throw new Error(code)
  }
  const type = response.headers.get('content-type')?.split(';')[0]?.trim().toLowerCase() ?? ''
  if (type !== 'application/json' && !/^application\/[a-z0-9.-]+\+json$/.test(type)) {
    return reject('UPSTREAM_INVALID_RESPONSE')
  }
  const declared = response.headers.get('content-length')
  if (declared !== null && (!/^\d+$/.test(declared) || Number(declared) > maxBytes)) {
    return reject('UPSTREAM_RESPONSE_TOO_LARGE')
  }
  const reader = response.body?.getReader()
  if (!reader) throw new Error('UPSTREAM_INVALID_RESPONSE')
  const chunks: Uint8Array[] = []
  let length = 0
  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      length += value.byteLength
      if (length > maxBytes) throw new Error('UPSTREAM_RESPONSE_TOO_LARGE')
      chunks.push(value)
    }
  } catch (error) {
    await reader.cancel().catch(() => {})
    throw error
  } finally {
    reader.releaseLock()
  }
  const bytes = new Uint8Array(length)
  let offset = 0
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength }
  try {
    const payload: unknown = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes))
    if (!payload || typeof payload !== 'object' || Array.isArray(payload) ||
      !Object.hasOwn(payload, 'data') || Object.hasOwn(payload, 'error')) throw new Error()
  } catch {
    throw new Error('UPSTREAM_INVALID_RESPONSE')
  }
  return bytes
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
  const id = operationId(request)
  const key = apiKey()
  if (!key) {
    return failure('SERVER_NOT_CONFIGURED', 'Canonical public API key is not configured', 503, id)
  }

  let target: URL
  try {
    target = canonicalUpstreamUrl(request)
  } catch {
    return failure('VALIDATION_ERROR', 'Invalid public API path', 422, id)
  }

  const requestId = id
  const headers: Record<string, string> = { apikey: key, accept: 'application/json' }
  if (requestId) headers['x-request-id'] = requestId

  try {
    const response = await fetch(target, {
      method: 'GET',
      headers,
      redirect: 'error',
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS)
    })
    if (!response.ok) {
      await response.body?.cancel().catch(() => {})
      const status = response.status >= 400 && response.status < 500 ? response.status : 502
      return failure(status < 500 ? 'UPSTREAM_REQUEST_REJECTED' : 'UPSTREAM_UNAVAILABLE', 'Canonical public API could not complete the request', status, id)
    }
    const bytes = await readCanonicalResponse(response)
    const outgoing = safeResponseHeaders(response.headers)
    outgoing.set('x-request-id', id)
    return new Response(bytes, { status: response.status, headers: outgoing })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    const code = ['UPSTREAM_RESPONSE_TOO_LARGE', 'UPSTREAM_INVALID_RESPONSE'].includes(message) ? message : 'UPSTREAM_UNAVAILABLE'
    const status = code === 'UPSTREAM_UNAVAILABLE' ? 503 : 502
    return failure(code, 'Canonical public API is unavailable', status, id)
  }
}

export async function readiness(request: Request): Promise<Response> {
  const id = operationId(request)
  if (!apiKey()) return failure('SERVER_NOT_CONFIGURED', 'Canonical API is not configured', 503, id)
  try {
    const response = await fetch(`${upstream}/surahs`, { headers: { apikey: apiKey(), 'x-request-id': id }, redirect: 'error', signal: AbortSignal.timeout(2000) })
    if (response.status !== 200) { await response.body?.cancel().catch(() => {}); throw new Error() }
    const payload = JSON.parse(new TextDecoder().decode(await readCanonicalResponse(response, 256 * 1024)))
    const rows = payload.data
    if (!Array.isArray(rows) || rows.length !== 114 || new Set(rows.map(row => row?.number)).size !== 114 || rows.some(row => !Number.isInteger(row?.number) || row.number < 1 || row.number > 114 || typeof row.name_ar !== 'string' || !row.name_ar || !Number.isInteger(row.ayah_count) || row.ayah_count < 1)) throw new Error()
    return Response.json({ ok: true, service: 'tarteel-api-elysia', request_id: id, failures: { ...failureCounters } }, { headers: { 'cache-control': 'no-store', 'x-request-id': id } })
  } catch { return failure('UPSTREAM_NOT_READY', 'Canonical catalog is not ready', 503, id) }
}

export const app = new Elysia({ name: 'tarteel-api-elysia' })
  .onError(({ request, code }) => failure(code === 'NOT_FOUND' ? 'NOT_FOUND' : 'INTERNAL_ERROR', code === 'NOT_FOUND' ? 'Endpoint not found' : 'Unexpected server error', code === 'NOT_FOUND' ? 404 : 500, operationId(request)))
  .get('/health', ({ request }) => readiness(request))
  .get('/v1/*', ({ request }) => proxyPublicRequest(request))

if (import.meta.main) {
  app.listen(Number(process.env.PORT ?? 3000))
  console.log(`Tarteel Elysia API listening on ${app.server?.hostname}:${app.server?.port}`)
}
