import { fetchJsonResponse, UpstreamHttpError } from './http.ts';

export const catalogSources: Record<string, { url: string; array: string[] }> = {
  sync_mp3quran_radios: { url: 'https://www.mp3quran.net/api/v3/radios?language=ar', array: ['radios'] },
  sync_islamic_radio_api_stations: { url: 'https://raw.githubusercontent.com/uthumany/islamic-radio-api/main/client/public/api/stations.json', array: ['stations'] },
  sync_islamic_app_radio_stations: { url: 'https://api.islamic.app/v1/radio/stations', array: ['data', 'stations'] },
};

export async function prepareCatalogRpc(name: string, args: Record<string, unknown>) {
  const source = Object.hasOwn(catalogSources, name) ? catalogSources[name] : undefined;
  if (!source) return { name, args };
  const response = await fetchJsonResponse(source.url);
  if (response.status !== 200) throw new UpstreamHttpError('PROVIDER_UNAVAILABLE', 503);
  const payload = await response.json();
  let rows = payload;
  for (const key of source.array) rows = rows?.[key];
  if (name === 'sync_mp3quran_radios') rows ??= payload?.Radios;
  if (!Array.isArray(rows) || rows.length === 0) throw new UpstreamHttpError('PROVIDER_INVALID_CATALOG');
  return { name: `${name}_payload`, args: { p_payload: payload } };
}
