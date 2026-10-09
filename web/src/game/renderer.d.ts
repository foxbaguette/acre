export type Weather = 'sun' | 'cloudy' | 'storm' | 'rain'
export type Daytime = 'morning' | 'day' | 'evening' | 'night'

export interface IslandView {
  setWeather(kind: Weather): void
  setDaytime(kind: Daytime): void
  /** Show the whole map. */
  fit(): void
  /** Zoom by factor f around the point (px, py) in view pixels. */
  zoomAt(f: number, px: number, py: number): void
  redraw(): void
  /** Resolves once the island is built and drawn. */
  ready: Promise<void>
  /** Internal handles for profiling in the console. */
  debug?: Record<string, unknown>
}

/**
 * Draws the island into the page's #view (with #field, #fx, #live, #weather, #labels canvases) and keeps it
 * alive: pan by dragging, zoom with the wheel, pinch, double-click and the #zin / #zout / #zfit buttons,
 * weather with [data-weather] buttons, the time of day with [data-daytime] buttons. Call once per page.
 */
export function startIsland(opts: { tiles: Uint8Array; mapId: string | number; weather?: Weather; daytime?: Daytime; cfg?: Record<string, unknown> }): IslandView
