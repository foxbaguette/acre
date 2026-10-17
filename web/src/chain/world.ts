// The world map's layout, as land.acre counts it (place_hash, open_sea): which places stay open sea, and where in its
// square each island lies, so the islands spread like an archipelago (never touching) and not like a grid.

/** A hash of a place (and a salt), the same 32-bit numbers the contract works with. */
export function placeHash(x: number, y: number, salt: number): number {
  let a = (Math.imul(x | 0, 0x9e3779b1) ^ Math.imul(y | 0, 0x85ebca77) ^ Math.imul(salt | 0, 0xc2b2ae3d)) >>> 0
  a = Math.imul((a ^ (a >>> 15)) >>> 0, 0x2c1b3c6d) >>> 0
  a = Math.imul((a ^ (a >>> 12)) >>> 0, 0x297a2d39) >>> 0
  return (a ^ (a >>> 15)) >>> 0
}

/** Whether a place stays open sea: a place has an island only where its hash beats all eight places round it, so no two
 *  islands ever touch (not even at a corner) and the sea between them runs from one place to wide reaches, about one
 *  place in nine an island. The middle of the world (0, 0) always beats its neighbours. */
export function openSea(x: number, y: number): boolean {
  const value = (px: number, py: number) => (px === 0 && py === 0 ? 4294967296 : placeHash(px, py, 1))
  const here = value(x, y)
  for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) if ((dx || dy) && value(x + dx, y + dy) >= here) return true
  return false
}

/** Where in its square an island lies: a shift of up to about a fifth of a square either way, the same every time. */
export function drift(x: number, y: number): { dx: number; dy: number } {
  return { dx: (placeHash(x, y, 3) / 4294967296 - 0.5) * 0.4, dy: (placeHash(x, y, 4) / 4294967296 - 0.5) * 0.4 }
}
