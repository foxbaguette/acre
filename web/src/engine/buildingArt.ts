// Written by tools/cottage.mjs. Where smoke rises from each building's chimneys, in tiles from its top-left corner.
export const CHIMNEYS: Record<string, [number, number][]> = {"building-farmhouse-1":[[1.82,1.77]],"building-farmhouse-2":[[2.02,1.62]],"building-farmhouse-3":[[2.16,1.49]],"building-farmhouse-4":[[2.16,1.49]],"building-farmhouse-5":[[2.16,1.49],[0.7,1.49]],"building-lab":[[2.74,1.48]]}
/** The buildings that light their windows after dark (a "<name>-lights" picture). */
export const LIT = new Set(["building-farmhouse-1","building-farmhouse-2","building-farmhouse-3","building-farmhouse-4","building-farmhouse-5","building-lab"])
