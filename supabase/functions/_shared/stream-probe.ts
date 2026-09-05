// Provider-operated domains only. Never allow tenant-controlled hostnames here.
const PROVIDER_DOMAINS = ['qurango.net', 'mp3quran.net', 'radiojar.com', 'holol.com', 'radio.co'];

export function trustedProbeUrl(value: unknown): string | null {
  if (typeof value !== 'string' || value.length > 4096) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:' || url.username || url.password || (url.port && url.port !== '443')) return null;
    if (!PROVIDER_DOMAINS.some(domain => url.hostname === domain || url.hostname.endsWith(`.${domain}`))) return null;
    return url.href;
  } catch { return null; }
}

export async function probeTrustedStream(value: unknown, fetcher: typeof fetch = globalThis.fetch) {
  const url = trustedProbeUrl(value);
  if (!url) return { ok: false, status: null, latency_ms: null, error: 'UNAPPROVED_STREAM_HOST' };
  const started = Date.now();
  const signal = AbortSignal.timeout(7000);
  try {
    const response = await fetcher(url, {
      headers: { range: 'bytes=0-4095', 'icy-metadata': '1', 'user-agent': 'Tarteel-Managed-Radio/1.0' },
      redirect: 'error', signal, cache: 'no-store',
    });
    await response.body?.cancel();
    const type = response.headers.get('content-type')?.split(';')[0]?.trim().toLowerCase() ?? '';
    const audio = /^audio\/[a-z0-9.+-]+$/.test(type) || ['application/ogg', 'application/vnd.apple.mpegurl', 'application/x-mpegurl'].includes(type);
    return {
      ok: (response.status === 200 || response.status === 206) && audio,
      status: response.status,
      latency_ms: Date.now() - started,
      content_type: audio ? type : null,
    };
  } catch {
    return { ok: false, status: null, latency_ms: Date.now() - started, error: signal.aborted ? 'STREAM_PROBE_TIMEOUT' : 'STREAM_PROBE_FAILED' };
  }
}
