export class UpstreamHttpError extends Error {
  code: string;
  status: number;
  constructor(code: string, status = 502) {
    super('Upstream request failed');
    this.code = code;
    this.status = status;
  }
}

// Buffer only a bounded JSON body. Keep the deadline active through body reads.
export async function fetchBoundedResponse(input: RequestInfo | URL, init: RequestInit = {},
  limits: { maxBytes?: number; timeoutMs?: number; format?: 'json' | 'audio' | 'xml' } = {}): Promise<Response> {
  const maxBytes = limits.maxBytes ?? 5 * 1024 * 1024;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), limits.timeoutMs ?? 12000);
  const signal = init.signal ? AbortSignal.any([init.signal, controller.signal]) : controller.signal;
  try {
    const response = await globalThis.fetch(input, { ...init, redirect: 'error', signal });
    if (!response.ok || response.status === 204) {
      await response.body?.cancel().catch(() => {});
      // Upstream error bodies can contain database details or credentials.
      return new Response(null, { status: response.status });
    }
    const type = response.headers.get('content-type')?.split(';')[0]?.trim().toLowerCase() ?? '';
    const declared = response.headers.get('content-length');
    const validType = limits.format === 'audio' ? /^(audio\/|application\/(octet-stream|ogg)$)/.test(type) : limits.format === 'xml' ? ['text/xml', 'application/xml'].includes(type) : (type === 'application/json' || /^application\/[a-z0-9.-]+\+json$/.test(type));
    if (!validType ||
      (declared !== null && !/^\d+$/.test(declared))) {
      await response.body?.cancel().catch(() => {});
      throw new UpstreamHttpError('UPSTREAM_INVALID_RESPONSE');
    }
    if (declared !== null && Number(declared) > maxBytes) {
      await response.body?.cancel().catch(() => {});
      throw new UpstreamHttpError('UPSTREAM_RESPONSE_TOO_LARGE');
    }
    const reader = response.body?.getReader();
    if (!reader) throw new UpstreamHttpError('UPSTREAM_INVALID_RESPONSE');
    const chunks: Uint8Array[] = [];
    let length = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        length += value.byteLength;
        if (length > maxBytes) throw new UpstreamHttpError('UPSTREAM_RESPONSE_TOO_LARGE');
        chunks.push(value);
      }
    } catch (error) {
      await reader.cancel().catch(() => {});
      throw error;
    } finally { reader.releaseLock(); }
    const bytes = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    try {
      if (limits.format === 'xml') {
        if (!/<return>1<\/return>/.test(new TextDecoder().decode(bytes))) throw new Error();
      } else if (limits.format !== 'audio') {
      const payload = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
      if (payload && typeof payload === 'object' && payload.error) throw new Error();
      }
    }
    catch { throw new UpstreamHttpError('UPSTREAM_INVALID_RESPONSE'); }
    const headers = new Headers(response.headers);
    // fetch has already decoded these bytes; do not describe them as compressed.
    headers.delete('content-encoding');
    headers.delete('content-length');
    return new Response(bytes, { status: response.status, headers });
  } catch (error) {
    if (error instanceof UpstreamHttpError) throw error;
    throw new UpstreamHttpError(signal.aborted ? 'UPSTREAM_TIMEOUT' : 'UPSTREAM_UNAVAILABLE', 503);
  } finally { clearTimeout(timer); }
}

export function fetchBackend(input: RequestInfo | URL, init: RequestInit = {}): Promise<Response> {
  const url = new URL(input instanceof Request ? input.url : String(input));
  const audio = url.pathname.startsWith('/storage/v1/object/');
  return fetchBoundedResponse(input, init, audio ? { format: 'audio', maxBytes: 52_428_800, timeoutMs: 60_000 } : {});
}
