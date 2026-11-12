(function (root) {
  "use strict";

  const LIVE_LIMIT = 18;
  const NUMBERED = 27;
  const FACE = ["一", "二", "三", "四", "五", "六", "七", "八", "九"];
  const SUITS = ["万", "筒", "条"];
  const FLOWERS = [..."东南西北中发白春夏秋冬梅兰竹菊"];
  const DIRECTIONS = ["东", "南", "西", "北"];
  const WIN_NAMES = { discard: "点炮", self: "自摸", three: "三金倒", sparrow: "金雀", grab: "抢金" };
  const MULTIPLIER = { discard: 1, self: 2, three: 3, sparrow: 4, grab: 5 };
  const MELD_NAMES = {
    chow: "吃", pong: "碰", kong: "明杠", addedKong: "补杠", concealedKong: "暗杠",
  };
  const PRIORITY = { win: 3, pong: 2, kong: 2, chow: 1, pass: 0 };

  function tileName(tile) {
    return tile < NUMBERED ? FACE[tile % 9] + SUITS[Math.floor(tile / 9)] : FLOWERS[tile - NUMBERED];
  }

  function makeWall(random = Math.random) {
    const wall = [];
    for (let tile = 0; tile < NUMBERED + FLOWERS.length; tile++) {
      wall.push(...Array(tile < 34 ? 4 : 1).fill(tile));
    }
    for (let index = wall.length - 1; index > 0; index--) {
      const other = Math.floor(random() * (index + 1));
      [wall[index], wall[other]] = [wall[other], wall[index]];
    }
    return wall;
  }

  function countTiles(tiles) {
    const counts = Array(NUMBERED).fill(0);
    for (const tile of tiles) counts[tile]++;
    return counts;
  }

  function goldCount(hand, gold) {
    return hand.filter(tile => tile === gold).length;
  }

  function groupSolver(counts) {
    const memo = new Map();

    function fits(wilds) {
      const tile = counts.findIndex(count => count > 0);
      if (tile === -1) return wilds % 3 === 0;
      const key = counts.join("") + wilds;
      if (memo.has(key)) return memo.get(key);
      const maxTriplet = Math.min(3, counts[tile]);
      for (let used = maxTriplet; used >= Math.max(1, 3 - wilds); used--) {
        counts[tile] -= used;
        const works = fits(wilds - (3 - used));
        counts[tile] += used;
        if (works) {
          memo.set(key, true);
          return true;
        }
      }

      const suitStart = tile - tile % 9;
      for (let start = Math.max(tile - 2, suitStart); start <= Math.min(tile, suitStart + 6); start++) {
        const others = [start, start + 1, start + 2].filter(other => other !== tile);
        counts[tile]--;
        const works = useSequence(others, 0, wilds);
        counts[tile]++;
        if (works) {
          memo.set(key, true);
          return true;
        }
      }
      memo.set(key, false);
      return false;
    }

    function useSequence(tiles, index, wilds) {
      if (index === tiles.length) return fits(wilds);
      const tile = tiles[index];
      if (counts[tile] > 0) {
        counts[tile]--;
        const works = useSequence(tiles, index + 1, wilds);
        counts[tile]++;
        if (works) return true;
      }
      return wilds > 0 && useSequence(tiles, index + 1, wilds - 1);
    }

    return fits;
  }

  function isWinningHand(hand, openCount, gold, goldPair = false) {
    if (openCount < 0 || openCount > 5 || hand.length !== (5 - openCount) * 3 + 2 ||
        hand.some(tile => tile < 0 || tile >= NUMBERED)) return false;

    const wilds = goldCount(hand, gold);
    const counts = countTiles(hand.filter(tile => tile !== gold));
    const fits = groupSolver(counts);
    if (wilds >= 2 && fits(wilds - 2)) return true;
    if (goldPair) return false;

    for (let tile = 0; tile < NUMBERED; tile++) {
      for (let used = Math.min(2, counts[tile]); used >= Math.max(1, 2 - wilds); used--) {
        counts[tile] -= used;
        const works = fits(wilds - (2 - used));
        counts[tile] += used;
        if (works) return true;
      }
    }
    return false;
  }

  function isIdleGold(hand, openCount, gold) {
    return hand.length === (5 - openCount) * 3 + 1 &&
      goldCount(hand, gold) === 1 && groupSolver(countTiles(hand.filter(tile => tile !== gold)))(0);
  }

  function scoreWin(winner, from, kind, hand, flowers, melds, gold) {
    const flowerCount = flowers.length;
    const golds = goldCount(hand, gold);
    const exposedKongs = melds.filter(meld => meld.type === "kong" || meld.type === "addedKong").length;
    const concealedKongs = melds.filter(meld => meld.type === "concealedKong").length;
    const base = 3 + flowerCount + golds + exposedKongs + 2 * concealedKongs;
    const multiplier = MULTIPLIER[kind];
    const perPayer = base * multiplier;
    const payers = from === null ? [0, 1, 2, 3].filter(seat => seat !== winner) : [from];
    const deltas = [0, 0, 0, 0];
    for (const payer of payers) deltas[payer] = -perPayer;
    deltas[winner] = perPayer * payers.length;
    return {
      kind, winner, from, base, multiplier, perPayer, payers, deltas,
      flowerCount, goldCount: golds, exposedKongs, concealedKongs,
    };
  }

  function action(type, data = {}) {
    const { kind, tile, tiles } = data;
    const id = [type, kind, tile, tiles?.join("-")].filter(part => part !== undefined).join(":");
    return { id, type, ...data };
  }

  function relativeOrder(first) {
    return [first, (first + 1) % 4, (first + 2) % 4, (first + 3) % 4];
  }

  function removeTile(hand, tile) {
    hand.splice(hand.indexOf(tile), 1);
  }

  class Game {
    constructor(random = Math.random) {
      this.random = random;
      this.scores = [0, 0, 0, 0];
      this.dealer = 0;
      this.round = 1;
      this.startRound();
    }

    startRound() {
      this.players = Array.from({ length: 4 }, () => ({
        hand: [], melds: [], flowers: [], river: [], discardedGold: false,
      }));
      this.wall = makeWall(this.random);
      this.gold = null;
      this.indicator = null;
      this.result = null;
      this.lastDiscard = null;
      this.latest = null;
      this.pending = null;
      const order = relativeOrder(this.dealer);

      for (let index = 0; index < 16; index++) {
        for (const seat of order) this.players[seat].hand.push(this.wall.shift());
      }
      this.players[this.dealer].hand.push(this.wall.shift());
      for (const player of this.players) {
        player.flowers = player.hand.filter(tile => tile >= NUMBERED);
        player.hand = player.hand.filter(tile => tile < NUMBERED);
      }

      let pendingFlowers = this.players.map(player => player.flowers.length);
      while (pendingFlowers.some(Boolean)) {
        const nextFlowers = [0, 0, 0, 0];
        for (const seat of order) {
          const player = this.players[seat];
          for (let count = 0; count < pendingFlowers[seat]; count++) {
            const tile = this.wall.pop();
            if (tile >= NUMBERED) {
              player.flowers.push(tile);
              nextFlowers[seat]++;
            } else {
              player.hand.push(tile);
            }
          }
        }
        pendingFlowers = nextFlowers;
      }

      let indicator = this.wall.pop();
      while (indicator >= NUMBERED) {
        this.players[this.dealer].flowers.push(indicator);
        indicator = this.wall.pop();
      }
      this.gold = indicator;
      this.indicator = indicator;
      this.current = this.dealer;
      this.canSelfWin = true;
      this.drawn = null;
      this.latest = { type: "start", seat: this.dealer };
      this.openClaims("three");
    }

    nextRound() {
      if (this.phase !== "result") return false;
      if (this.result.winner !== null && this.result.winner !== this.dealer) {
        this.dealer = (this.dealer + 1) % 4;
      }
      this.round++;
      this.startRound();
      return true;
    }

    openClaims(kind) {
      const order = relativeOrder(this.dealer);
      const offers = order.map(seat => {
        const { hand } = this.players[seat];
        const offer = [];
        if (kind === "three" && goldCount(hand, this.gold) === 3) {
          offer.push(action("win", { kind }));
        }
        if (kind === "grab") {
          if (seat === this.dealer) {
            for (const tile of new Set(hand)) {
              const changed = [...hand];
              removeTile(changed, tile);
              changed.push(this.gold);
              if (isWinningHand(changed, 0, this.gold)) {
                offer.push(action("win", { kind, tile }));
              }
            }
          } else if (isWinningHand([...hand, this.gold], 0, this.gold)) {
            offer.push(action("win", { kind }));
          }
        }
        return offer;
      });

      if (this.beginClaims("opening", order, offers, { kind })) return;
      if (kind === "three") this.openClaims("grab");
      else this.phase = "turn";
    }

    beginClaims(phase, order, offers, details) {
      const eligible = order.filter((_, index) => offers[index].length);
      if (!eligible.length) return false;
      this.phase = phase;
      this.pending = {
        ...details, eligible, replies: new Map(),
        options: new Map(eligible.map(seat => [seat, [...offers[order.indexOf(seat)], action("pass")]])),
      };
      return true;
    }

    winKind(seat, incoming) {
      const { hand, melds, discardedGold } = this.players[seat];
      const self = incoming === undefined;
      if (!self && (discardedGold || isIdleGold(hand, melds.length, this.gold))) return null;
      if (self && goldCount(hand, this.gold) === 3) return "three";
      const full = self ? hand : [...hand, incoming];
      if (goldCount(full, this.gold) >= 2 && isWinningHand(full, melds.length, this.gold, true)) {
        return "sparrow";
      }
      return isWinningHand(full, melds.length, this.gold) ? (self ? "self" : "discard") : null;
    }

    actions(seat) {
      if (this.phase === "opening" || this.phase === "reaction") {
        if (this.pending.replies.has(seat)) return [];
        return this.pending.options.get(seat) || [];
      }
      if (this.phase !== "turn" || this.current !== seat) return [];

      const { hand, melds } = this.players[seat];
      const options = [];
      const kind = this.canSelfWin ? this.winKind(seat) : null;
      if (kind) options.push(action("win", { kind }));
      if (this.canSelfWin && this.wall.length > LIVE_LIMIT) {
        const counts = countTiles(hand);
        counts.forEach((count, tile) => {
          if (tile === this.gold) return;
          if (count === 4) options.push(action("concealedKong", { tile }));
          if (count && melds.some(meld => meld.type === "pong" && meld.tiles[0] === tile)) {
            options.push(action("addedKong", { tile }));
          }
        });
      }
      return [...options, ...[...new Set(hand)].sort((a, b) => a - b).map(tile => action("discard", { tile }))];
    }

    reactionActions(seat, from, tile) {
      if (tile === this.gold) return [];
      const { hand } = this.players[seat];
      const options = [];
      const kind = this.winKind(seat, tile);
      if (kind) options.push(action("win", { kind }));
      const counts = countTiles(hand);
      if (counts[tile] >= 2) options.push(action("pong", { tile, tiles: [tile, tile] }));
      if (counts[tile] >= 3 && this.wall.length > LIVE_LIMIT) {
        options.push(action("kong", { tile, tiles: [tile, tile, tile] }));
      }
      if (seat !== (from + 1) % 4) return options;

      const suitStart = tile - tile % 9;
      for (let start = Math.max(tile - 2, suitStart); start <= Math.min(tile, suitStart + 6); start++) {
        const tiles = [start, start + 1, start + 2].filter(other => other !== tile);
        if (tiles.every(other => other !== this.gold && counts[other] > 0)) {
          options.push(action("chow", { tile, tiles }));
        }
      }
      return options;
    }

    act(seat, id) {
      const move = this.actions(seat).find(option => option.id === id);
      if (!move) return false;
      if (this.phase === "opening" || this.phase === "reaction") {
        this.pending.replies.set(seat, move);
        if (this.pending.replies.size === this.pending.eligible.length) this.resolveClaims();
      } else if (move.type === "discard") {
        this.discard(seat, move.tile);
      } else if (move.type === "win") {
        this.finishWin(seat, null, move.kind);
      } else {
        this.selfKong(seat, move);
      }
      return true;
    }

    discard(seat, tile) {
      const player = this.players[seat];
      removeTile(player.hand, tile);
      player.river.push(tile);
      if (tile === this.gold) player.discardedGold = true;
      this.drawn = null;
      this.lastDiscard = { seat, tile };
      this.latest = { type: "discard", seat, tile };
      const next = (seat + 1) % 4;
      const order = relativeOrder(next).slice(0, 3);
      const offers = order.map(other => this.reactionActions(other, seat, tile));
      if (!this.beginClaims("reaction", order, offers, { from: seat, tile })) {
        this.draw(next, false);
      }
    }

    resolveClaims() {
      const { eligible, replies, from, tile, kind } = this.pending;
      const candidates = eligible.filter(seat => replies.get(seat).type !== "pass");
      // Stable sort preserves the original seat order for equal claims.
      candidates.sort((a, b) => PRIORITY[replies.get(b).type] - PRIORITY[replies.get(a).type]);
      const winner = candidates[0];
      this.pending = null;

      if (this.phase === "opening") {
        if (winner === undefined) {
          if (kind === "three") this.openClaims("grab");
          else this.phase = "turn";
          return;
        }
        if (kind === "grab") {
          const player = this.players[winner];
          if (winner === this.dealer) {
            const discarded = replies.get(winner).tile;
            removeTile(player.hand, discarded);
            player.river.push(discarded);
          }
          player.hand.push(this.indicator);
          this.indicator = null;
        }
        this.finishWin(winner, null, kind);
        return;
      }

      if (winner === undefined) {
        this.draw((from + 1) % 4, false);
        return;
      }
      const move = replies.get(winner);
      this.players[from].river.pop();
      this.lastDiscard = null;
      const player = this.players[winner];
      if (move.type === "win") {
        player.hand.push(tile);
        this.finishWin(winner, from, move.kind);
        return;
      }
      for (const own of move.tiles) removeTile(player.hand, own);
      player.melds.push({ type: move.type, tiles: [...move.tiles, tile].sort((a, b) => a - b), from });
      this.latest = { type: move.type, seat: winner, tile };
      if (move.type === "kong") this.draw(winner, true);
      else {
        this.current = winner;
        this.phase = "turn";
        this.canSelfWin = false;
      }
    }

    selfKong(seat, move) {
      const { type, tile } = move;
      const { hand, melds } = this.players[seat];
      if (type === "concealedKong") {
        for (let count = 0; count < 4; count++) removeTile(hand, tile);
        melds.push({ type, tiles: [tile, tile, tile, tile], from: seat });
      } else {
        removeTile(hand, tile);
        const meld = melds.find(entry => entry.type === "pong" && entry.tiles[0] === tile);
        meld.type = type;
        meld.tiles.push(tile);
      }
      this.latest = { type, seat, tile: type === "concealedKong" ? null : tile };
      this.draw(seat, true);
    }

    draw(seat, supplement) {
      const player = this.players[seat];
      while (this.wall.length > LIVE_LIMIT) {
        const tile = supplement ? this.wall.pop() : this.wall.shift();
        if (tile < NUMBERED) {
          player.hand.push(tile);
          this.current = seat;
          this.phase = "turn";
          this.canSelfWin = true;
          this.drawn = tile;
          return;
        }
        player.flowers.push(tile);
        supplement = true;
      }
      this.finish({ kind: "draw", winner: null, from: null, deltas: [0, 0, 0, 0] });
    }

    finishWin(winner, from, kind) {
      const { hand, flowers, melds } = this.players[winner];
      this.finish(scoreWin(winner, from, kind, hand, flowers, melds, this.gold));
    }

    finish(result) {
      this.result = result;
      this.scores = this.scores.map((score, seat) => score + result.deltas[seat]);
      this.phase = "result";
    }

    view(seat) {
      const reveal = this.phase === "result";
      return {
        seat, dealer: this.dealer, round: this.round, gold: this.gold, indicator: this.indicator,
        scores: [...this.scores], current: this.current, phase: this.phase,
        opening: this.phase === "opening" ? this.pending.kind : null,
        remaining: this.wall.length - LIVE_LIMIT, lastDiscard: this.lastDiscard,
        drawn: this.current === seat && this.phase === "turn" ? this.drawn : null,
        latest: this.latest, result: this.result,
        players: this.players.map((player, other) => ({
          hand: other === seat || reveal ? [...player.hand] : undefined,
          count: player.hand.length, river: [...player.river], flowers: [...player.flowers],
          discardedGold: player.discardedGold,
          melds: player.melds.map(meld => ({
            ...meld,
            tiles: other === seat || reveal || meld.type !== "concealedKong" ?
              [...meld.tiles] : [null, null, null, null],
          })),
        })),
      };
    }
  }

  const mahjong = {
    Game, makeWall, tileName, countTiles, isWinningHand, isIdleGold, scoreWin,
    DIRECTIONS, WIN_NAMES, MELD_NAMES, NUMBERED,
  };
  if (typeof module !== "undefined") module.exports = mahjong;
  else root.Mahjong = mahjong;
}(globalThis));
