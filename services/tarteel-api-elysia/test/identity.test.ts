import { describe, expect, test } from 'bun:test'
import {
  assertSameCanonicalIdentity,
  assertSameIdentity,
  canonicalIdentityKey,
  identityKey,
  toCanonicalIdentityV1
} from '../src/identity'

describe('Quran reciter identity', () => {
  test('same provider reciter and edition is stable', () => {
    const value = {
      provider: 'mp3quran' as const,
      reciterId: 'mp3quran:10:20',
      edition: '10-20'
    }
    expect(identityKey(value)).toBe('mp3quran|mp3quran:10:20|10-20')
    expect(() => assertSameIdentity(value, value)).not.toThrow()
  })

  test('different human reciter is rejected even on same provider', () => {
    expect(() =>
      assertSameIdentity(
        {
          provider: 'mp3quran',
          reciterId: 'mp3quran:10:20',
          edition: '10-20'
        },
        {
          provider: 'mp3quran',
          reciterId: 'mp3quran:99:88',
          edition: '99-88'
        }
      )
    ).toThrow('QURAN_AUDIO_RECITER_MISMATCH')
  })

  test('cross-provider substitution is rejected', () => {
    expect(() =>
      assertSameIdentity(
        {
          provider: 'mp3quran',
          reciterId: 'mp3quran:10:20',
          edition: '10-20'
        },
        {
          provider: 'alquran-cloud',
          reciterId: 'alquran:ar.alafasy',
          edition: 'ar.alafasy'
        }
      )
    ).toThrow('QURAN_AUDIO_RECITER_MISMATCH')
  })

  test('MP3Quran legacy boundary maps to canonical v1 without losing moshaf or surah', () => {
    const canonical = toCanonicalIdentityV1(
      {
        provider: 'mp3quran',
        reciterId: 'mp3quran:10:20',
        edition: '10-20'
      },
      36,
      { riwayah: 'Hafs' }
    )
    expect(canonical).toEqual({
      schema_version: 1,
      provider: 'MP3QURAN',
      provider_reciter_id: '10',
      edition: '10-20',
      moshaf_id: '20',
      riwayah: 'Hafs',
      surah_number: 36,
      ayah_number: null
    })
  })

  test('AlQuran Cloud identity must match its selected edition exactly', () => {
    expect(() =>
      toCanonicalIdentityV1(
        {
          provider: 'alquran-cloud',
          reciterId: 'alquran:ar.alafasy',
          edition: 'ar.abdulbasitmurattal'
        },
        1
      )
    ).toThrow('ALQURAN_EDITION_IDENTITY_MISMATCH')
  })

  test('MP3Quran moshaf/edition substitution is rejected', () => {
    expect(() =>
      toCanonicalIdentityV1(
        {
          provider: 'mp3quran',
          reciterId: 'mp3quran:10:20',
          edition: '10-99'
        },
        1
      )
    ).toThrow('MP3QURAN_EDITION_MISMATCH')
  })

  test('wrong surah identity is rejected by canonical comparison', () => {
    const selected = toCanonicalIdentityV1(
      {
        provider: 'mp3quran',
        reciterId: 'mp3quran:10:20',
        edition: '10-20'
      },
      1
    )
    const resolved = toCanonicalIdentityV1(
      {
        provider: 'mp3quran',
        reciterId: 'mp3quran:10:20',
        edition: '10-20'
      },
      2
    )
    expect(() => assertSameCanonicalIdentity(selected, resolved)).toThrow(
      'QURAN_AUDIO_RECITER_MISMATCH'
    )
  })

  test('riwayah is enforceable when the caller has an explicit expected value', () => {
    const selected = toCanonicalIdentityV1(
      {
        provider: 'mp3quran',
        reciterId: 'mp3quran:10:20',
        edition: '10-20'
      },
      1,
      { riwayah: 'Hafs' }
    )
    const resolved = toCanonicalIdentityV1(
      {
        provider: 'mp3quran',
        reciterId: 'mp3quran:10:20',
        edition: '10-20'
      },
      1,
      { riwayah: 'Warsh' }
    )
    expect(() =>
      assertSameCanonicalIdentity(selected, resolved, { requireRiwayah: true })
    ).toThrow('QURAN_AUDIO_RECITER_MISMATCH')
  })

  test('canonical key includes provider-owned identity, moshaf and requested passage', () => {
    const value = toCanonicalIdentityV1(
      {
        provider: 'mp3quran',
        reciterId: 'mp3quran:10:20',
        edition: '10-20'
      },
      114,
      { ayahNumber: 6 }
    )
    expect(canonicalIdentityKey(value)).toBe('MP3QURAN|10|10-20|20||114|6')
  })
})
