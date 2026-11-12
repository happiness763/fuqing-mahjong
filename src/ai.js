(function (root) {
  "use strict";

  const { countTiles, isWinningHand, NUMBERED } =
    typeof module !== "undefined" ? require("./mahjong") : root.Mahjong;

  function removeTiles(hand, tiles) {
    const copy = [...hand];
    for (const tile of tiles) copy.splice(copy.indexOf(tile), 1);
    return copy;
  }

  function visibleCounts(view) {
    const visible = view.players.flatMap(player => [
      ...player.river,
      ...player.melds.flatMap(meld => meld.tiles.filter(tile => tile !== null)),
    ]);
    if (view.indicator !== null) visible.push(view.indicator);
    return countTiles(visible);
  }

  // Allocate natural tiles to melds, two-tile blocks and the pair, scoring each
  // tile only once. Gold is valued separately and exact waits break close ties.
  function shapeEvaluator() {
    const cache = new Map();

    function strength(counts, slots, pairAvailable) {
      const tile = counts.findIndex(count => count > 0);
      if (tile < 0 || (slots === 0 && !pairAvailable)) return 0;
      const key = counts.join("") + slots + Number(pairAvailable);
      if (cache.has(key)) return cache.get(key);

      function take(tiles, usedSlot, usedPair, points) {
        for (const used of tiles) counts[used]--;
        const score = points + strength(counts, slots - usedSlot, pairAvailable && !usedPair);
        for (const used of tiles) counts[used]++;
        return score;
      }

      let best = take([tile], 0, false, 0);
      const count = counts[tile];
      if (count >= 2 && pairAvailable) best = Math.max(best, take([tile, tile], 0, true, 1));
      if (slots > 0) {
        if (count >= 2) best = Math.max(best, take([tile, tile], 1, false, 1));
        if (count >= 3) best = Math.max(best, take([tile, tile, tile], 1, false, 2));
        const rank = tile % 9;
        const adjacent = rank < 8 && counts[tile + 1];
        const gap = rank < 7 && counts[tile + 2];
        if (adjacent) best = Math.max(best, take([tile, tile + 1], 1, false, 1));
        if (gap) best = Math.max(best, take([tile, tile + 2], 1, false, 1));
        if (adjacent && gap) best = Math.max(best, take([tile, tile + 1, tile + 2], 1, false, 2));
      }
      cache.set(key, best);
      return best;
    }

    return strength;
  }

  function chooseAction(view, actions) {
    const win = actions.find(move => move.type === "win");
    if (win || actions.length <= 1) return win || actions[0];

    const { hand, melds } = view.players[view.seat];
    const { gold } = view;
    const known = visibleCounts(view);
    const own = countTiles(hand);
    const strength = shapeEvaluator();

    function rating(tiles, open) {
      const counts = countTiles(tiles);
      const wilds = counts[gold];
      counts[gold] = 0;
      const shape = open * 2 + strength(counts, 5 - open, true) + wilds * 1.45;
      if (shape < 8) return shape;

      let outs = 0;
      for (let tile = 0; tile < NUMBERED; tile++) {
        const available = 4 - known[tile] - own[tile];
        if (available > 0 && isWinningHand([...tiles, tile], open, gold)) outs += available;
      }
      return outs > 0 ? 15 + outs * 0.07 + shape * 0.01 : shape;
    }

    function discardRating(tiles, open, tile) {
      const position = tile % 9;
      const safety = (known[tile] + (position === 0 || position === 8 ? 1 : 0)) * 0.015;
      const protectGold = tile === gold ? -3 : 0;
      return rating(removeTiles(tiles, [tile]), open) + safety + protectGold;
    }

    const pass = actions.find(move => move.type === "pass");
    if (pass) {
      let best = pass;
      let bestRating = rating(hand, melds.length) + 0.23;
      for (const move of actions) {
        if (move === pass) continue;
        const tiles = removeTiles(hand, move.tiles);
        const open = melds.length + 1;
        const nextRating = move.type === "kong" ? rating(tiles, open) + 0.35 :
          Math.max(...[...new Set(tiles)].map(tile => discardRating(tiles, open, tile)));
        if (nextRating > bestRating) {
          best = move;
          bestRating = nextRating;
        }
      }
      return best;
    }

    let best;
    let bestRating = -Infinity;
    for (const move of actions) {
      let nextRating;
      if (move.type === "discard") {
        nextRating = discardRating(hand, melds.length, move.tile);
      } else if (move.type === "concealedKong") {
        nextRating = rating(removeTiles(hand, [move.tile, move.tile, move.tile, move.tile]), melds.length + 1) + 0.35;
      } else {
        nextRating = rating(removeTiles(hand, [move.tile]), melds.length) + 0.35;
      }
      if (nextRating > bestRating) {
        best = move;
        bestRating = nextRating;
      }
    }
    return best;
  }

  const ai = { chooseAction };
  if (typeof module !== "undefined") module.exports = ai;
  else root.MahjongAI = ai;
}(globalThis));
