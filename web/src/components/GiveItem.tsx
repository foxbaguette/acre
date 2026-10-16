import { useEffect, useState } from 'react'

import { fetchIsAuthorizer } from '@/chain/admin'
import { CONTRACT } from '@/chain/config'
import { GROUND_ITEMS, type BuildCfg } from '@/chain/inventory'
import { contractActions } from '@/chain/rpc'
import { friendlyError, signer, transact } from '@/wallet/session'

/** For testing, and only for land.acre's authorizers: adds something to the island owner's inventory, free (giveitem). */
export function GiveItem({ owner, buildCfg, onGiven }: { owner: string | null; buildCfg: BuildCfg[]; onGiven: () => void }) {
  const who = signer()
  const [allowed, setAllowed] = useState(false)
  const [item, setItem] = useState('path')
  const [amount, setAmount] = useState(10)
  const [note, setNote] = useState<string | null>(null)
  useEffect(() => {
    let live = true
    if (!who) { setAllowed(false); return }
    Promise.all([fetchIsAuthorizer(who.actor), contractActions()]).then(([auth, acts]) => live && setAllowed(auth && acts.includes('giveitem')), () => undefined)
    return () => { live = false }
  }, [who?.actor])   // eslint-disable-line react-hooks/exhaustive-deps
  if (!allowed || !who || !owner) return null
  const choices = [...buildCfg.map((c) => ({ name: c.name, label: c.display || c.name })), ...GROUND_ITEMS.map((n) => ({ name: n, label: n }))]
  const give = async () => {
    if (!Number.isInteger(amount) || amount < 1 || amount > 65535) { setNote('a whole number from 1 to 65535'); return }
    setNote('Waiting for your wallet…')
    try {
      await transact([{ account: CONTRACT, name: 'giveitem', authorization: [who], data: { wallet: who.actor, owner, building_name: item, amount } }])
      setNote(`${amount} ${choices.find((c) => c.name === item)?.label ?? item} added.`); setTimeout(onGiven, 2500)
    } catch (e) { setNote(friendlyError(e)) }
  }
  return (
    <div className="give-item">
      <span className="build-group">testing: add to {owner === who.actor ? 'your' : `${owner}’s`} inventory</span>
      <div className="give-row">
        <select value={item} onChange={(e) => setItem(e.target.value)}>{choices.map((c) => <option key={c.name} value={c.name}>{c.label}</option>)}</select>
        <input type="number" min={1} max={65535} step={1} value={amount} onChange={(e) => setAmount(Number(e.target.value))} aria-label="how many" />
        <button type="button" className="build-link" onClick={give}>add</button>
      </div>
      {note && <small className="give-note" role="status">{note}</small>}
    </div>
  )
}
