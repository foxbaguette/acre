// The island view's public shape: what the game page (and the chain readers) use.
import type { Building, Builds, BuildTool } from './build'
export type { Building, Builds, BuildTool }
export type Weather = 'sun' | 'cloudy' | 'storm' | 'rain'
export type Daytime = 'morning' | 'day' | 'evening' | 'night'
export type Season = 'spring' | 'summer' | 'autumn' | 'winter'

/** A creature from the chain. size and speed are per mille of the species' standard (1000 = standard). */
export interface Lifeform {
  id: number | string
  species: string
  /** the five colour roles as hex without '#', e.g. '516a47' */
  colors: string[]
  size: number
  speed: number
  /** where its species lives (life.acre species environments): pond, sea, land, beach; none: where its picture belongs */
  environments?: string[]
}

export interface IslandView {
  setWeather(kind: Weather): void
  setDaytime(kind: Daytime): void
  setSeason(kind: Season): void
  /** Called with the season, daytime and weather shown, now and whenever one changes (a button or a set call). */
  onConditions(fn: (c: { season: Season; daytime: Daytime; weather: Weather }) => void): void
  /** Shows these creatures on the island (replacing any shown before); resolves to how many could be placed. */
  setLifeforms(list: Lifeform[]): Promise<number>
  /** The enclosures the chain keeps: a tag with their number over each (id, tiles inside, first tile as a map index). */
  setEnclosures(list: { id: string; tiles: number; at: number; water?: boolean }[]): void
  /** Selects the creature with this id (a glowing ring beneath it), or none with null. */
  selectCreature(id: number | string | null): void
  /** Flies to a creature and selects it. */
  showCreature(id: number | string): void
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
  /** Turns the building about to be placed a quarter turn (also the R key). */
  rotateBuild(): void
  /** Takes back the last build; false when there was none. */
  undoBuild(): boolean
  /** The player asks for a harvest of these fully grown tiles (map indexes): the page sends it to the chain. */
  /** ripe tiles to harvest: for seeds or for the storage when a field's ring says so, otherwise as the page's tool has it */
  onHarvest(fn: (tiles: number[], forSeeds?: boolean) => void): void
  /** tiles whose harvest still waiting for a farmer is called off */
  onCancelHarvest(fn: (tiles: number[]) => void): void
  /** stops drawing while something covers the whole island (the bestiary), and goes on after */
  setPaused(paused: boolean): void
  /** The farmers' jobs (land.acre workqueue), crops named. */
  setJobs(jobs: import('./farmers').Job[]): void
  /** What grows, by map index: crop name and when it was sown (ms). */
  setPlants(plants: Record<number, { c: string; t: number }>): void
  /** How long each crop takes to grow, ms, by crop name. */
  setGrowth(growth: Record<string, number>): void
  /** Called with every build on the island whenever they change (to keep them), and whether undo can take one back;
   *  what stands changed (builds: what stands), or the plan did (pending: how many tiles it changes) */
  onBuild(fn: (builds: Builds, undoable: boolean, pending: number, kind: 'build' | 'erase' | 'both', fenced: PenLoss, left: Inventory | null) => void): void
  /** What the island's owner holds (null: no limit), and the inventory name of each building (buildcfg's building_name). */
  setInventory(held: Inventory | null, names: Partial<Record<string, string>>): void
  /** The owner's seeds by crop name (null: not counted): sowing is held to them. */
  setSeeds(held: Record<string, number> | null): void
  /** What is left of the seeds once the plan is sown (null: not counted). */
  seedsLeft(): Record<string, number> | null
  /** What would stand once the plan is confirmed (a copy). */
  plan(): Builds
  /** Builds what was planned. */
  confirmBuild(): void
  /** Drops what was planned. */
  discardBuild(): void
  /** Internal handles for profiling in the console. */
  debug?: Record<string, unknown>
}

/** What a plan's enclosures take away when it is confirmed: soil tiles, and the buildings not made to stand inside one. */
export interface PenLoss { soil: number; buildings: string[] }

/** What a player holds, by inventory name (soil, path, fence, tree, or a building's building_name): how many. */
export type Inventory = Record<string, number>
