import { describe, expect, test } from 'bun:test'
import { assertSameIdentity, identityKey } from '../src/identity'

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
})
