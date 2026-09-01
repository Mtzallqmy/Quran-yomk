export type QuranAudioProvider = 'alquran-cloud' | 'mp3quran'

export interface ReciterIdentity {
  provider: QuranAudioProvider
  reciterId: string
  edition: string
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
