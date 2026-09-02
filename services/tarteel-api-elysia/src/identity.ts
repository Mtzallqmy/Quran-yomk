export type QuranAudioProvider = 'alquran-cloud' | 'mp3quran'
export type CanonicalQuranAudioProvider = 'ALQURAN_CLOUD' | 'MP3QURAN'

export interface ReciterIdentity {
  provider: QuranAudioProvider
  reciterId: string
  edition: string
}

export interface CanonicalReciterIdentityV1 {
  schema_version: 1
  provider: CanonicalQuranAudioProvider
  provider_reciter_id: string
  edition: string
  moshaf_id: string | null
  riwayah: string | null
  surah_number: number
  ayah_number: number | null
}

const mismatch = (reason: string) => {
  throw new Error(`QURAN_AUDIO_RECITER_MISMATCH:${reason}`)
}

const assertSurah = (surahNumber: number) => {
  if (!Number.isInteger(surahNumber) || surahNumber < 1 || surahNumber > 114) {
    mismatch('SURAH_NUMBER_INVALID')
  }
}

const parseMp3StableIdentity = (identity: ReciterIdentity) => {
  const match = /^mp3quran:(\d+):(\d+)$/.exec(identity.reciterId)
  if (!match) mismatch('MP3QURAN_RECITER_ID_INVALID')
  const providerReciterId = match![1]
  const moshafId = match![2]
  if (identity.edition !== `${providerReciterId}-${moshafId}`) {
    mismatch('MP3QURAN_EDITION_MISMATCH')
  }
  return { providerReciterId, moshafId }
}

export const toCanonicalIdentityV1 = (
  identity: ReciterIdentity,
  surahNumber: number,
  options: { riwayah?: string | null; ayahNumber?: number | null } = {}
): CanonicalReciterIdentityV1 => {
  assertSurah(surahNumber)
  const ayahNumber = options.ayahNumber ?? null
  if (ayahNumber !== null && (!Number.isInteger(ayahNumber) || ayahNumber < 1)) {
    mismatch('AYAH_NUMBER_INVALID')
  }

  if (identity.provider === 'mp3quran') {
    const parsed = parseMp3StableIdentity(identity)
    return {
      schema_version: 1,
      provider: 'MP3QURAN',
      provider_reciter_id: parsed.providerReciterId,
      edition: identity.edition,
      moshaf_id: parsed.moshafId,
      riwayah: options.riwayah?.trim() || null,
      surah_number: surahNumber,
      ayah_number: ayahNumber
    }
  }

  if (identity.reciterId !== `alquran:${identity.edition}`) {
    mismatch('ALQURAN_EDITION_IDENTITY_MISMATCH')
  }
  return {
    schema_version: 1,
    provider: 'ALQURAN_CLOUD',
    provider_reciter_id: identity.edition,
    edition: identity.edition,
    moshaf_id: null,
    riwayah: options.riwayah?.trim() || null,
    surah_number: surahNumber,
    ayah_number: ayahNumber
  }
}

export const canonicalIdentityKey = (
  identity: CanonicalReciterIdentityV1,
  includeRiwayah = true
) =>
  [
    identity.provider,
    identity.provider_reciter_id,
    identity.edition,
    identity.moshaf_id ?? '',
    includeRiwayah ? identity.riwayah ?? '' : '',
    String(identity.surah_number),
    identity.ayah_number == null ? '' : String(identity.ayah_number)
  ].join('|')

export const assertSameCanonicalIdentity = (
  requested: CanonicalReciterIdentityV1,
  resolved: CanonicalReciterIdentityV1,
  options: { requireRiwayah?: boolean } = {}
) => {
  const includeRiwayah = options.requireRiwayah ?? false
  if (
    canonicalIdentityKey(requested, includeRiwayah) !==
    canonicalIdentityKey(resolved, includeRiwayah)
  ) {
    mismatch(
      `${canonicalIdentityKey(requested, includeRiwayah)}:${canonicalIdentityKey(
        resolved,
        includeRiwayah
      )}`
    )
  }
}

export const identityKey = (identity: ReciterIdentity) =>
  `${identity.provider}|${identity.reciterId}|${identity.edition}`

export const assertSameIdentity = (
  requested: ReciterIdentity,
  resolved: ReciterIdentity
) => {
  if (identityKey(requested) !== identityKey(resolved)) {
    throw new Error(
      `QURAN_AUDIO_RECITER_MISMATCH:${identityKey(requested)}:${identityKey(resolved)}`
    )
  }
}
