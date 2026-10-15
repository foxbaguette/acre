import { useEffect, useState } from 'react'

import { TOKEN_DECIMALS } from '@/chain/config'
import { fetchFenBalance, formatFen } from '@/chain/token'

/** The player's Fenmarks: a small paper tag with the coin and how many they own. */
export function FenPurse({ account }: { account: string }) {
  const [amount, setAmount] = useState((0).toFixed(TOKEN_DECIMALS))
  useEffect(() => {
    let live = true
    fetchFenBalance(account).then((a) => live && setAmount(a))
    return () => { live = false }
  }, [account])
  return (
    <div className="purse" title="Fenmarks (FEN) in this wallet">
      <img src="art/token/fenmark-small.svg" width="28" height="28" alt="" />
      <span>
        <b>{formatFen(amount)}</b>
        <small>FEN</small>
      </span>
    </div>
  )
}
