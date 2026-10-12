export const CHAIN_ID = '1064487b3cd1a897ce03ae5b6a865651747e2e152090f99c1d19d44e01aea5a4'

export const APP_NAME = 'Unclaimed Acres'

/** The game contract: table maps (scope = contract) and one chunks table per map (scope = map id). */
export const CONTRACT = 'land.acre'

/** The generator config (land.acre table genconfig) the atlas picks first for a new island. */
export const GEN_CONFIG = '0'

/** The creatures contract: table creatures (scope = contract), secondary index 3 = by_map (map_id). */
export const LIFE_CONTRACT = 'life.acre'

/** WAX API nodes (CORS verified), one per operator. Reads try them in turn. */
export const RPC_NODES: readonly string[] = [
  'https://wax.greymass.com',
  'https://api.wax.alohaeos.com',
  'https://wax.eosphere.io',
  'https://api.waxsweden.org',
  'https://wax.eosusa.io',
  'https://wax.cryptolions.io'
]

/** Maps are 100 x 100 tiles, stored as 10 x 10 chunks of 10 x 10 tiles (chunk id = cy * 10 + cx). */
export const MAP_SIZE = 100
export const CHUNK = 10
