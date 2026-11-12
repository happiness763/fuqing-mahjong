const { test } = require("node:test");
const assert = require("node:assert/strict");
const { Game, makeWall } = require("../src/mahjong");
const { chooseAction } = require("../src/ai");

function seeded(seed) {
  return () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed / 2 ** 32;
  };
}

test("AI chooses the isolated discard to make a live wait and retains gold", () => {
  const game = new Game(seeded(12));
  game.gold = 26;
  game.phase = "turn";
  game.players[0].hand = [0, 1, 2, 3, 4, 5, 9, 9, 9, 12, 13, 14, 20, 21, 23, 23, 26];
  const options = game.actions(0).filter(move => move.type === "discard");
  const move = chooseAction(game.view(0), options);
  assert.notEqual(move.tile, 26);
  assert.ok([20, 21, 23].includes(move.tile));
});

test("30 seeded AI games finish with all 144 tiles and balanced scores", () => {
  const expected = makeWall(() => 0).sort((a, b) => a - b);
  let wins = 0;
  for (let seed = 1; seed <= 15; seed++) {
    const game = new Game(seeded(seed));
    for (let round = 1; round <= 2; round++) {
      let actions = 0;
      while (game.phase !== "result") {
        const seat = [0, 1, 2, 3].find(candidate => game.actions(candidate).length);
        assert.notEqual(seat, undefined, "game has an actor");
        const legal = game.actions(seat);
        const move = chooseAction(game.view(seat), legal);
        assert.ok(game.act(seat, move.id), "AI took a legal action");
        assert.ok(++actions < 300, "round ends within 300 actions");
      }
      const tiles = [
        ...game.wall,
        ...game.players.flatMap(p => [...p.hand, ...p.flowers, ...p.river, ...p.melds.flatMap(m => m.tiles)]),
      ];
      if (game.indicator !== null) tiles.push(game.indicator);
      assert.deepEqual(tiles.sort((a, b) => a - b), expected);
      assert.equal(game.scores.reduce((sum, score) => sum + score, 0), 0);
      assert.equal(game.round, round);
      if (game.result.winner !== null) wins++;
      assert.ok(game.nextRound());
    }
  }
  assert.ok(wins > 0, "AI can complete a winning hand");
});
