const cache = new Map<string, Promise<string>>()

/**
 * A creature picture in a creature's own colours: the SVG's five colour roles default to `var(--cN, #hex)`,
 * and those defaults are swapped for the given hex colours (without '#'). Resolves to a data URL for an <img>.
 */
export function recolouredArt(url: string, colors: string[]): Promise<string> {
  const key = url + '|' + colors.join(',')
  let p = cache.get(key)
  if (!p) {
    p = fetch(url)
      .then((r) => {
        if (!r.ok) throw new Error(`${url}: ${r.status}`)
        return r.text()
      })
      .then((svg) => {
        colors.forEach((hex, i) => {
          if (/^[0-9a-f]{6}$/i.test(hex)) svg = svg.replace(new RegExp(`(--c${i + 1},\\s*)#[0-9A-Fa-f]{3,8}`), `$1#${hex}`)
        })
        return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg)
      })
    p.catch(() => cache.delete(key))
    cache.set(key, p)
  }
  return p
}
