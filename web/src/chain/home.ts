import type { Daytime, Season, Weather } from '@/engine/types'

import { readTable } from './rpc'

/** The island clock: home.acre keeps when it started and how long a season, a daytime and a weather last; they then
 *  simply take turns from that start, seasons and daytimes in index order, the weather from the season's own list. */
export const HOME_CONTRACT = 'home.acre'

export interface HomeClock {
  /** ms since 1970 */
  start: number
  /** seconds each lasts */
  season: number
  daytime: number
  weather: number
  seasons: Season[]
  daytimes: Daytime[]
  /** per season, its weathers in turn */
  weathers: Record<string, Weather[]>
}

export interface Conditions { season: Season; daytime: Daytime; weather: Weather }

interface ConfigRow { index: number; time_start: string; season_duration: number | string; daytime_duration: number | string; weather_duration: number | string }
interface NamedRow { index: number | string; season_name?: string; daytime_name?: string; weather_name?: string }

const WEATHER: Record<string, Weather> = { sunny: 'sun', sun: 'sun', cloudy: 'cloudy', lightrain: 'rain', rain: 'rain', storm: 'storm' }
const byIndex = (a: NamedRow, b: NamedRow) => Number(a.index) - Number(b.index)
const q = { code: HOME_CONTRACT }

export async function fetchHomeClock(): Promise<HomeClock> {
  const [config, seasons, daytimes] = await Promise.all([
    readTable<ConfigRow>('config', HOME_CONTRACT, (r) => r.length > 0, q),
    readTable<NamedRow>('seasons', HOME_CONTRACT, (r) => r.length > 0, q),
    readTable<NamedRow>('daytimes', HOME_CONTRACT, (r) => r.length > 0, q),
  ])
  const c = config.find((r) => Number(r.index) === 0) ?? config[0]
  const seasonNames = seasons.sort(byIndex).map((r) => r.season_name as Season)
  const weathers: Record<string, Weather[]> = {}
  await Promise.all(seasonNames.map(async (s) => {
    const rows = await readTable<NamedRow>('weather', s, (r) => r.length > 0, q)
    weathers[s] = rows.sort(byIndex).map((r) => WEATHER[r.weather_name ?? ''] ?? 'sun')
  }))
  return {
    start: Date.parse(c.time_start.endsWith('Z') ? c.time_start : c.time_start + 'Z'),
    season: Number(c.season_duration), daytime: Number(c.daytime_duration), weather: Number(c.weather_duration),
    seasons: seasonNames, daytimes: daytimes.sort(byIndex).map((r) => r.daytime_name as Daytime), weathers,
  }
}

/** Which turn each is on at a moment (counting from the start), and so what the island has then. */
export function clockAt(c: HomeClock, ms: number) {
  const t = Math.max(0, (ms - c.start) / 1000)
  const turn = { season: Math.floor(t / c.season), daytime: Math.floor(t / c.daytime), weather: Math.floor(t / c.weather) }
  const season = c.seasons[turn.season % c.seasons.length] ?? 'summer'
  const list = c.weathers[season] ?? []
  const now: Conditions = { season, daytime: c.daytimes[turn.daytime % c.daytimes.length] ?? 'day', weather: list.length ? list[turn.weather % list.length] : 'sun' }
  // the next moment anything changes, ms since 1970
  const next = c.start + 1000 * Math.min((turn.season + 1) * c.season, (turn.daytime + 1) * c.daytime, (turn.weather + 1) * c.weather)
  return { now, turn, next }
}

/** The time on the island: one island day is all the daytimes once round (morning from 6:00, each daytime six hours),
 *  and which day of the season it is. */
export function islandTime(c: HomeClock, ms: number) {
  const t = Math.max(0, (ms - c.start) / 1000), dayLen = c.daytime * Math.max(1, c.daytimes.length)
  const minutes = Math.floor(((t % dayLen) / dayLen) * 24 * 60 + 6 * 60) % (24 * 60)
  const day = Math.floor((t % c.season) / dayLen) + 1, days = Math.ceil(c.season / dayLen)
  return { h: Math.floor(minutes / 60), m: minutes % 60, day, days }
}
