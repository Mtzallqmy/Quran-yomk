import { afterEach, describe, expect, test } from 'bun:test'
import { app, canonicalUpstreamUrl, readCanonicalResponse } from '../src/index'

const originalFetch = globalThis.fetch
const originalKey = process.env.TARTEEL_API_KEY

afterEach(() => {
  globalThis.fetch = originalFetch
  if (originalKey == null) delete process.env.TARTEEL_API_KEY
  else process.env.TARTEEL_API_KEY = originalKey
})

describe('upstream failure boundaries', () => {
  for (const [body, type] of [
    ['<html>internal token</html>', 'text/html'],
    ['not-json', 'application/json'],
    ['[]', 'application/json'],
    ['{}', 'application/json'],
    ['{"error":{"message":"internal token"}}', 'application/json'],
  ]) {
    test(`rejects invalid success payload ${body}`, async () => {
      process.env.TARTEEL_API_KEY = 'test'
      globalThis.fetch = (async () => new Response(body, { headers: { 'content-type': type! } })) as typeof fetch
      const response = await app.handle(new Request('https://adapter.invalid/v1/app-config'))
      expect(response.status).toBe(502)
      expect(await response.text()).not.toContain('internal token')
    })
  }

  test('stops chunked responses at the limit and cancels the source', async () => {
    let cancelled = false
    const stream = new ReadableStream<Uint8Array>({
      pull(controller) { controller.enqueue(new Uint8Array(8)) },
      cancel() { cancelled = true },
    })
    await expect(readCanonicalResponse(new Response(stream, {
      headers: { 'content-type': 'application/json' },
    }), 12)).rejects.toThrow('UPSTREAM_RESPONSE_TOO_LARGE')
    expect(cancelled).toBe(true)
  })

  test('rejects an oversized declared response before consuming it', async () => {
    let cancelled = false
    const stream = new ReadableStream<Uint8Array>({ cancel() { cancelled = true } })
    await expect(readCanonicalResponse(new Response(stream, {
      headers: { 'content-type': 'application/json', 'content-length': '99' },
    }), 12)).rejects.toThrow('UPSTREAM_RESPONSE_TOO_LARGE')
    expect(cancelled).toBe(true)
  })

  test('never forwards upstream database errors or secret-bearing headers', async () => {
    process.env.TARTEEL_API_KEY = 'test'
    globalThis.fetch = (async () => new Response('password=internal-secret', {
      status: 500, headers: { 'set-cookie': 'token=internal-secret' },
    })) as typeof fetch
    const response = await app.handle(new Request('https://adapter.invalid/v1/app-config'))
    expect(response.status).toBe(502)
    expect(response.headers.get('set-cookie')).toBeNull()
    expect(await response.text()).not.toContain('internal-secret')
  })

  test('enforces redirect rejection and an abort signal; network errors stay private', async () => {
    process.env.TARTEEL_API_KEY = 'test'
    globalThis.fetch = (async (_input: unknown, init?: RequestInit) => {
      expect(init?.redirect).toBe('error')
      expect(init?.signal).toBeInstanceOf(AbortSignal)
      throw new Error('provider token=internal-secret')
    }) as typeof fetch
    const response = await app.handle(new Request('https://adapter.invalid/v1/app-config'))
    expect(response.status).toBe(503)
    expect(await response.text()).not.toContain('internal-secret')
  })
})

describe('canonical public API proxy', () => {
  test('maps /v1 paths and query parameters only to the canonical upstream', () => {
    const target = canonicalUpstreamUrl(new Request('https://adapter.invalid/v1/quran/reciters?surah=36'))
    expect(target.origin).toBe('https://qkroecnecdxghcqvvoxn.supabase.co')
    expect(target.pathname).toBe('/functions/v1/tarteel-api/quran/reciters')
    expect(target.search).toBe('?surah=36')
  })

  test('forwards API key and request id and preserves upstream response semantics', async () => {
    process.env.TARTEEL_API_KEY = 'sb_publishable_test'
    const calls: Array<{ url: string; init?: RequestInit }> = []
    globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
      calls.push({ url: String(input), init })
      return new Response(JSON.stringify({ data: { ok: true } }), {
        status: 206,
        headers: {
          'content-type': 'application/json',
          'cache-control': 'public, max-age=30',
          'x-request-id': 'upstream-id'
        }
      })
    }) as typeof fetch

    const response = await app.handle(new Request('https://adapter.invalid/v1/app-config', {
      headers: { 'x-request-id': 'client-id' }
    }))
    expect(response.status).toBe(206)
    expect(await response.json()).toEqual({ data: { ok: true } })
    expect(response.headers.get('x-tarteel-api-adapter')).toBe('elysia-proxy')
    const called = calls[0]
    expect(called?.url).toBe('https://qkroecnecdxghcqvvoxn.supabase.co/functions/v1/tarteel-api/app-config')
    const headers = new Headers(called?.init?.headers)
    expect(headers.get('apikey')).toBe('sb_publishable_test')
    expect(headers.get('x-request-id')).toBe('client-id')
  })

  test('fails closed when the canonical upstream key is missing', async () => {
    delete process.env.TARTEEL_API_KEY
    const response = await app.handle(new Request('https://adapter.invalid/v1/app-config'))
    expect(response.status).toBe(503)
    const body = await response.json() as { error: { code: string } }
    expect(body.error.code).toBe('SERVER_NOT_CONFIGURED')
  })
})
