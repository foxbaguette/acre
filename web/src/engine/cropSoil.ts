// The soil each crop with a picture likes best, as a starting point for its config (Farming › Crops): pH, then moisture
// and nutrients in percent. Real crops after their usual growing guides (moisture: how wet they like their soil; nutrients:
// how heavily they feed, legumes and herbs light, brassicas, maize and cucurbits heavy); the island's own inventions
// (glowcap, moonbloom, ember-pepper, milk-pouch ...) after what they look like. The chain keeps acidity as pH x 10.

/** name: [pH, moisture %, nutrients %] */
const SOIL: Record<string, [number, number, number]> = {
  banana: [6.0, 75, 80], basil: [6.5, 55, 55], beans: [6.5, 55, 35], beetroot: [6.8, 55, 55], 'bell-pepper': [6.5, 60, 70],
  'blue-java': [6.0, 75, 80], blueberries: [4.8, 65, 40], broccoli: [6.8, 65, 75], 'buddhas-hand': [6.0, 50, 60], cabbage: [6.8, 65, 75],
  cacao: [6.0, 80, 70], 'carolina-reaper': [6.5, 55, 65], carrots: [6.3, 50, 40], champignon: [7.0, 85, 90], chanterelle: [5.0, 75, 35],
  coffee: [5.5, 65, 65], corn: [6.3, 60, 85], cucumber: [6.5, 75, 70], 'custard-apple': [6.5, 55, 55], 'dragon-fruit': [6.5, 30, 45],
  durian: [5.8, 80, 70], 'egg-plant': [6.3, 60, 70], eggplant: [6.3, 60, 70], 'ember-pepper': [6.8, 25, 60], 'finger-lime': [6.0, 50, 55],
  garlic: [6.5, 45, 50], glowcap: [5.5, 90, 65], grapes: [6.5, 35, 40], jabuticaba: [5.8, 70, 55], kiwano: [6.8, 40, 50],
  kiwi: [6.0, 65, 65], lemon: [6.2, 50, 60], lettuce: [6.5, 70, 55], lime: [6.2, 50, 60], mandarin: [6.2, 50, 60],
  mangosteen: [5.8, 80, 65], 'milk-pouch': [7.2, 70, 60], mint: [6.8, 80, 55], monstera: [6.0, 70, 60], moonbloom: [6.0, 65, 50],
  oats: [6.2, 50, 45], olive: [7.2, 25, 35], orange: [6.2, 50, 60], peanuts: [6.0, 40, 30], peas: [6.8, 60, 35],
  pineapple: [5.0, 45, 45], pineberry: [5.8, 60, 55], 'pink-guava': [6.0, 55, 55], potatoes: [5.5, 60, 65], pumpkin: [6.5, 60, 80],
  radish: [6.5, 55, 40], rambutan: [5.5, 80, 65], raspberries: [6.0, 60, 55], 'red-cabbage': [6.8, 65, 75], 'red-wheat': [6.5, 45, 60],
  rice: [6.0, 95, 65], rye: [6.0, 40, 40], salak: [5.5, 80, 60], 'spring-onions': [6.5, 60, 50], strawberries: [6.0, 60, 55],
  'sugar-cane': [6.5, 80, 80], sunflower: [6.5, 40, 55], thyme: [7.0, 25, 25], tomatoes: [6.5, 60, 75], watermelon: [6.3, 55, 60],
  wheat: [6.5, 45, 60], zucchini: [6.5, 65, 70],
}

/** The soil a crop likes best, as the chain keeps it (acidity: pH x 10), or null for a name not in the list. */
export function likedSoil(name: string): { nutrients: number; moisture: number; acidity: number } | null {
  const s = SOIL[name.trim().toLowerCase().replace(/\s+/g, '-')]
  return s ? { acidity: Math.round(s[0] * 10), moisture: s[1], nutrients: s[2] } : null
}
