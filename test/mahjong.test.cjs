const { test } = require("node:test");
const assert = require("node:assert/strict");
const { Game, makeWall, isWinningHand, isIdleGold, scoreWin } = require("../src/mahjong");

const groups = [0, 1, 2, 3, 4, 5, 9, 9, 9, 18, 19, 20, 23, 24, 25];
const sampleHand = [...groups, 14, 14];

function seeded(seed) {
  return () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed / 2 ** 32;
  };
}

test("deck contains 108 numbered tiles and 36 flowers", () => {
  const wall = makeWall(seeded(9));
  assert.equal(wall.length, 144);
  assert.equal(wall.filter(tile => tile >= 27).length, 36);
  for (let tile = 0; tile < 42; tile++) {
    assert.equal(wall.filter(t => t === tile).length, tile < 34 ? 4 : 1);
  }
});

test("five groups and a pair, with open melds and wild substitutions", () => {
  assert.equal(isWinningHand(sampleHand, 0, 26), true);
  assert.equal(isWinningHand([...groups, 14, 26], 0, 26), true);
  assert.equal(isWinningHand([4, 5, 26, 9, 9], 4, 26), true);
  assert.equal(isWinningHand([8, 9, 10, 14, 14], 4, 26), false);
  assert.equal(isWinningHand([0, 1, 2, 26, 26], 4, 26, true), true);
  assert.equal(isWinningHand([0, 1, 26, 26, 26], 4, 26, true), true);
  assert.equal(isWinningHand([0, 4, 26, 26, 26], 4, 26, true), false);
  assert.equal(isWinningHand([3, 3, 4, 5, 26], 4, 26, true), false);
  assert.equal(isWinningHand([0, 1, 2, 3], 4, 26), false);
});

test("an idle gold hand has one wild and all other tiles form groups", () => {
  assert.equal(isIdleGold([...groups, 26], 0, 26), true);
  assert.equal(isIdleGold([...groups.slice(1), 15, 26], 0, 26), false);
  assert.equal(isIdleGold([...groups.slice(3), 26], 1, 26), true);
});

test("scoring distinguishes self draw, discard and kongs", () => {
  const result = scoreWin(0, null, "self", [26], [27, 34], [], 26);
  assert.equal(result.perPayer, 12);
  assert.deepEqual(result.deltas, [36, -12, -12, -12]);
  const sparrow = scoreWin(1, 3, "sparrow", [26, 26], [], [
    { type: "concealedKong" }, { type: "addedKong" }, { type: "kong" },
  ], 26);
  assert.equal(sparrow.base, 9);
  assert.deepEqual(sparrow.deltas, [0, 36, 0, -36]);
});

test("starting round fills each hand, opens a numbered gold and hides opponents", () => {
  const game = new Game(seeded(43));
  assert.deepEqual(game.players.map(p => p.hand.length), [17, 16, 16, 16]);
  assert.ok(game.players.every(p => p.hand.every(t => t < 27)));
  assert.ok(game.gold >= 0 && game.gold < 27);
  const view = game.view(0);
  assert.equal(view.players[1].hand, undefined);
  assert.equal(view.players[1].count, 16);
  assert.equal(view.players[0].hand.length, 17);
  assert.equal(view.remaining, game.wall.length - 18);
});

function fixture() {
  const game = new Game(seeded(11));
  game.players.forEach(p => Object.assign(p, {
    hand: [], melds: [], flowers: [], river: [], discardedGold: false,
  }));
  game.gold = 26;
  game.indicator = 26;
  game.wall = Array(20).fill(2);
  game.phase = "turn";
  game.current = 0;
  game.canSelfWin = true;
  game.result = null;
  return game;
}

function act(game, seat, type, tile) {
  const action = game.actions(seat).find(a => a.type === type && (tile === undefined || a.tile === tile));
  assert.ok(action, `Missing action ${type} for seat ${seat}`);
  assert.equal(game.act(seat, action.id), true);
}

test("a distant pong beats a chow and cannot resolve before all choices", () => {
  const game = fixture();
  game.players[0].hand = [4, 8];
  game.players[1].hand = [2, 3];
  game.players[3].hand = [4, 4];
  act(game, 0, "discard", 4);
  act(game, 1, "chow");
  assert.equal(game.phase, "reaction");
  act(game, 3, "pong");
  assert.equal(game.current, 3);
  assert.equal(game.players[3].melds[0].type, "pong");
  assert.deepEqual(game.players[0].river, []);
  assert.equal(game.actions(3).some(a => a.type === "win"), false);
});

test("discarded gold is unclaimable and its owner cannot claim a later win", () => {
  const game = fixture();
  game.players[0].hand = [26];
  game.players[1].hand = [...groups, 14];
  act(game, 0, "discard", 26);
  assert.equal(game.players[0].discardedGold, true);
  assert.equal(game.current, 1);
  game.players[0].hand = [...groups, 14];
  act(game, 1, "discard", 14);
  assert.equal(game.actions(0).some(a => a.type === "win"), false);
});

test("two discard winners resolve in seat order regardless of response order", () => {
  const game = fixture();
  game.players[0].hand = [14];
  game.players[1].hand = [...groups, 14];
  game.players[2].hand = [...groups, 14];
  act(game, 0, "discard", 14);
  act(game, 2, "win");
  assert.equal(game.phase, "reaction");
  act(game, 1, "win");
  assert.equal(game.result.winner, 1);
  assert.deepEqual(game.result.deltas, [-3, 3, 0, 0]);
  game.nextRound();
  assert.equal(game.dealer, 1);
  assert.deepEqual(game.scores, [-3, 3, 0, 0]);
});

test("last live flower flows with zero points and dealer stays", () => {
  const game = fixture();
  game.wall = [34, ...Array(18).fill(2)];
  game.players[0].hand = [8];
  act(game, 0, "discard", 8);
  assert.equal(game.result.kind, "draw");
  assert.deepEqual(game.players[1].flowers, [34]);
  assert.equal(game.wall.length, 18);
  game.nextRound();
  assert.equal(game.dealer, 0);
});

test("concealed and added kongs supplement from the tail and hide a concealed kong", () => {
  const game = fixture();
  game.wall.push(6);
  game.players[0].hand = [3, 3, 3, 3, 8];
  act(game, 0, "concealedKong", 3);
  assert.deepEqual(game.players[0].hand, [8, 6]);
  assert.deepEqual(game.view(1).players[0].melds[0].tiles, [null, null, null, null]);
  game.players[0].melds.push({ type: "pong", tiles: [6, 6, 6], from: 1 });
  act(game, 0, "addedKong", 6);
  assert.equal(game.players[0].melds[1].tiles.length, 4);
  assert.equal(game.players[0].melds[1].type, "addedKong");
});

test("opening three gold precedes a grab and a grab uses the displayed tile", () => {
  const three = fixture();
  three.players[0].hand = [...groups, 14, 8];
  three.players[1].hand = [...groups.slice(0, 13), 26, 26, 26];
  three.openClaims("three");
  assert.deepEqual(three.actions(0), []);
  act(three, 1, "win");
  assert.equal(three.result.kind, "three");
  const grab = fixture();
  grab.players[0].hand = [...groups, 14, 8];
  grab.openClaims("three");
  act(grab, 0, "win", 8);
  assert.equal(grab.result.kind, "grab");
  assert.equal(grab.indicator, null);
  assert.equal(grab.players[0].hand.at(-1), 26);
  assert.equal(grab.players[0].river.at(-1), 8);
});
