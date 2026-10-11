// The island view's public shape: what the game page (and the chain readers) use.
import type { Building, Builds, BuildTool } from './build'
export type { Building, Builds, BuildTool }
export type Weather = 'sun' | 'cloudy' | 'storm' | 'rain'
export type Daytime = 'morning' | 'day' | 'evening' | 'night'

/** A creature from the chain. size and speed are per mille of the species' standard (1000 = standard). */
export interface Lifeform {
  id: number | string
  species: string
  /** the five colour roles as hex without '#', e.g. '516a47' */
  colors: string[]
  size: number
  speed: number
}

export interface IslandView {
  setWeather(kind: Weather): void
  setDaytime(kind: Daytime): void
  /** Shows these creatures on the island (replacing any shown before); resolves to how many could be placed. */
  setLifeforms(list: Lifeform[]): Promise<number>
  /** Selects the creature with this id (a glowing ring beneath it), or none with null. */
  selectCreature(id: number | string | null): void
  /** The art folder for a species name (e.g. "creatures__kitsune"), or null when there is no sprite for it. */
  spriteFor(species: string): string | null
  /** Called with the id of the creature the player clicked or tapped, or null when they clicked elsewhere. */
  onSelect(fn: (id: number | string | null) => void): void
  /** Show the whole map. */
  fit(): void
  /** Zoom by factor f around the point (px, py) in view pixels. */
  zoomAt(f: number, px: number, py: number): void
  redraw(): void
  /** Resolves once the island is built and drawn. */
  ready: Promise<void>
  /** Picks what a drag on the map does: fence in an area, lay a path, turn grass into soil, sow a crop (which one:
   *  crop), put up or upgrade a building, erase, or nothing (the map pans again). */
  setBuildTool(tool: BuildTool | null, crop?: string): void
  /** Takes back the last build; false when there was none. */
  undoBuild(): boolean
  /** Called with every build on the island whenever they change (to keep them), and whether undo can take one back. */
  onBuild(fn: (builds: Builds, undoable: boolean) => void): void
  /** Internal handles for profiling in the console. */
  debug?: Record<string, unknown>
}
