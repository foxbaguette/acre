/** This address with ?admin set or removed (the island left out), keeping anything else (like ?as=). */
export function withAdmin(on: boolean) {
  const p = new URLSearchParams(location.search)
  p.delete('island')
  if (on) p.set('admin', '')
  else p.delete('admin')
  const q = p.toString().replace(/admin=(&|$)/, 'admin$1')
  return location.pathname + (q ? `?${q}` : '')
}

/** This address with ?world set or removed (the island and admin left out), keeping anything else (like ?as=). */
export function withWorld(on: boolean) {
  const p = new URLSearchParams(location.search)
  p.delete('island'); p.delete('admin')
  if (on) p.set('world', ''); else p.delete('world')
  const q = p.toString().replace(/world=(&|$)/, 'world$1')
  return location.pathname + (q ? `?${q}` : '')
}
