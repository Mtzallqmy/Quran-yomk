import { Elysia, t } from 'elysia'
import { assertSameIdentity, type ReciterIdentity } from './identity'

const upstream = (process.env.TARTEEL_UPSTREAM_API ??
  'https://qkroecnecdxghcqvvoxn.supabase.co/functions/v1/tarteel-api').replace(/\/$/, '')
const upstreamKey = process.env.TARTEEL_API_KEY ?? ''

const json = async (url: string) => {
  const response = await fetch(url, {
    headers: upstreamKey ? { apikey: upstreamKey, accept: 'application/json' } : { accept: 'application/json' }
  })
  if (!response.ok) throw new Error(`UPSTREAM_HTTP_${response.status}`)
  return response.json() as Promise<Record<string, unknown>>
}

const mp3Reciters = async (surah?: number) => {
  const query = new URLSearchParams({ language: 'ar' })
  if (surah) query.set('sura', String(surah))
  const response = await fetch(`https://www.mp3quran.net/api/v3/reciters?${query}`)
  if (!response.ok) throw new Error(`MP3QURAN_HTTP_${response.status}`)
  const root = (await response.json()) as { reciters?: Array<Record<string, unknown>> }
  const rows: Array<Record<string, unknown>> = []
  for (const reciter of root.reciters ?? []) {
    const reciterId = Number(reciter.id ?? 0)
    const name = String(reciter.name ?? '')
    for (const raw of (reciter.moshaf as Array<Record<string, unknown>> | undefined) ?? []) {
      const moshafId = Number(raw.id ?? 0)
      const edition = `${reciterId}-${moshafId}`
      const server = String(raw.server ?? '').replace(/\/+$/, '')
      const surahs = String(raw.surah_list ?? '')
        .split(',')
        .map(Number)
        .filter((value) => Number.isInteger(value) && value >= 1 && value <= 114)
      if (!reciterId || !moshafId || !server.startsWith('https://') || !surahs.length) continue
      rows.push({
        id: `mp3quran:${reciterId}:${moshafId}`,
        provider: 'mp3quran',
        providerReciterId: String(reciterId),
        edition,
        nameAr: name,
        nameEn: name,
        riwayah: String(raw.name ?? ''),
        availableSurahs: surahs,
        server
      })
    }
  }
  return rows
}

const alQuranReciters = async () => {
  const response = await fetch('https://api.alquran.cloud/v1/edition/format/audio')
  if (!response.ok) throw new Error(`ALQURAN_HTTP_${response.status}`)
  const root = (await response.json()) as { data?: Array<Record<string, unknown>> }
  return (root.data ?? [])
    .filter((row) => row.language === 'ar')
    .map((row) => {
      const edition = String(row.identifier ?? '')
      return {
        id: `alquran:${edition}`,
        provider: 'alquran-cloud',
        providerReciterId: `alquran:${edition}`,
        edition,
        nameAr: String(row.name ?? edition),
        nameEn: String(row.englishName ?? edition),
        riwayah: String(row.type ?? ''),
        availableSurahs: Array.from({ length: 114 }, (_, index) => index + 1),
        bitrates: [64, 128, 192]
      }
    })
    .filter((row) => row.edition.length > 0)
}

export const app = new Elysia({ name: 'tarteel-api-elysia' })
  .get('/health', () => ({ ok: true, service: 'tarteel-api-elysia' }))
  .get('/v1/app-config', async () => json(`${upstream}/app-config`))
  .get(
    '/v1/quran/reciters',
    async ({ query }) => {
      const surah = query.surah ? Number(query.surah) : undefined
      const [mp3, alquran] = await Promise.allSettled([
        mp3Reciters(surah),
        alQuranReciters()
      ])
      return {
        data: [
          ...(mp3.status === 'fulfilled' ? mp3.value : []),
          ...(alquran.status === 'fulfilled' ? alquran.value : [])
        ]
      }
    },
    { query: t.Object({ surah: t.Optional(t.String({ pattern: '^[0-9]{1,3}$' })) }) }
  )
  .get(
    '/v1/quran/audio/resolve',
    async ({ query, set }) => {
      const surah = Number(query.surah)
      const bitrate = Number(query.bitrate ?? 128)
      const requested: ReciterIdentity = {
        provider: query.provider,
        reciterId: query.reciterId,
        edition: query.edition
      }

      if (query.provider === 'alquran-cloud') {
        const resolved: ReciterIdentity = {
          provider: 'alquran-cloud',
          reciterId: `alquran:${query.edition}`,
          edition: query.edition
        }
        assertSameIdentity(requested, resolved)
        const safeBitrate = [64, 128, 192].includes(bitrate) ? bitrate : 128
        return {
          data: {
            identity: resolved,
            surah,
            bitrate: safeBitrate,
            playbackUrl: `https://cdn.islamic.network/quran/audio-surah/${safeBitrate}/${encodeURIComponent(query.edition)}/${surah}.mp3`
          }
        }
      }

      const rows = await mp3Reciters(surah)
      const match = rows.find(
        (row) => row.id === query.reciterId && row.edition === query.edition
      )
      if (!match) {
        set.status = 404
        return { error: { code: 'RECITER_OR_SURAH_NOT_FOUND' } }
      }
      const resolved: ReciterIdentity = {
        provider: 'mp3quran',
        reciterId: String(match.id),
        edition: String(match.edition)
      }
      assertSameIdentity(requested, resolved)
      return {
        data: {
          identity: resolved,
          nameAr: match.nameAr,
          riwayah: match.riwayah,
          surah,
          bitrate: 0,
          playbackUrl: `${match.server}/${String(surah).padStart(3, '0')}.mp3`
        }
      }
    },
    {
      query: t.Object({
        provider: t.Union([t.Literal('alquran-cloud'), t.Literal('mp3quran')]),
        reciterId: t.String({ minLength: 1 }),
        edition: t.String({ minLength: 1 }),
        surah: t.String({ pattern: '^(?:[1-9]|[1-9][0-9]|1[01][0-4])$' }),
        bitrate: t.Optional(t.String({ pattern: '^[0-9]{2,3}$' }))
      })
    }
  )

if (import.meta.main) {
  app.listen(Number(process.env.PORT ?? 3000))
  console.log(`Tarteel Elysia API listening on ${app.server?.hostname}:${app.server?.port}`)
}
