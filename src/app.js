(() => {
  "use strict";

  const { Game, tileName, DIRECTIONS, WIN_NAMES, MELD_NAMES } = Mahjong;
  const { chooseAction } = MahjongAI;
  const $ = id => document.getElementById(id);
  const YOU = 0;
  const SEATS = [0, 1, 2, 3];
  const NAMES = ["你", "阿岚", "阿榕", "阿屿"];
  const AVATARS = ["你", "岚", "榕", "屿"];
  const LOCATIONS = ["本家", "右家", "对家", "左家"];
  const TILE_SUITS = ["Man", "Pin", "Sou"];
  const rules = $("rules-dialog");
  const reset = $("reset-dialog");
  const resultDialog = $("result-dialog");

  let game;
  let timer;
  let selected;
  let history;
  let lastEvent;
  let shownResult;

  function drawFace(tile) {
    if (tile >= 27) return `<span class="flower-face">${tileName(tile)}</span>`;
    const face = TILE_SUITS[Math.floor(tile / 9)] + (tile % 9 + 1);
    return `<img class="tile-art" src="godot/assets/tiles/${face}.svg" alt="" draggable="false">`;
  }

  function tileMarkup(tile, gold, options = {}) {
    const { compact, last, index, picked, drawn } = options;
    const tag = index === undefined ? "span" : "button";
    const classes = ["tile", compact && "tile-compact", tile === null && "tile-back",
      tile !== null && tile === gold && "is-gold", last && "last", picked && "selected", drawn && "drawn"];
    if (tile === null) return `<span class="${classes.filter(Boolean).join(" ")}" aria-hidden="true"></span>`;
    const label = tileName(tile) + (tile === gold ? "，金牌" : "") + (drawn ? "，刚摸到" : "");
    const attributes = tag === "button" ?
      `type="button" data-index="${index}" data-tile="${tile}" aria-pressed="${Boolean(picked)}"` : "";
    return `<${tag} class="${classes.filter(Boolean).join(" ")}" ${attributes} title="${label}" aria-label="${label}"${tag === "span" ? ' role="img"' : ""}>${drawFace(tile)}${tile === gold ? '<span class="gold-badge" aria-hidden="true">金</span>' : ""}</${tag}>`;
  }

  function meldMarkup(meld, gold) {
    return `<span class="meld" title="${MELD_NAMES[meld.type]}">${meld.tiles.map(tile => tileMarkup(tile, gold, { compact: true })).join("")}</span>`;
  }

  function direction(seat, view) {
    return DIRECTIONS[(seat - view.dealer + 4) % 4];
  }

  function scoreLabel(score) {
    return score > 0 ? `+${score}` : String(score);
  }

  function scoreClass(score) {
    return score > 0 ? "positive" : score < 0 ? "negative" : "";
  }

  function resultTitle(result) {
    if (result.winner === null) return "本局流局";
    const method = result.kind === "discard" ? "胡牌" : WIN_NAMES[result.kind];
    const source = result.from === null ? "" : ` · ${NAMES[result.from]}点炮`;
    return `${NAMES[result.winner]}${method}${source}`;
  }

  function seatMarkup(seat, view, active) {
    const player = view.players[seat];
    const flowerTitle = player.flowers.length ? player.flowers.map(tileName).join("、") : "暂无花牌";
    const label = `<div class="seat-card${active ? " active" : ""}">
      <span class="seat-avatar avatar-${seat}" aria-hidden="true">${AVATARS[seat]}</span>
      <div><span class="seat-name">${NAMES[seat]}${seat === view.dealer ? '<span class="dealer-tag">庄</span>' : ""}</span>
      <span class="seat-sub" title="${flowerTitle}">${direction(seat, view)}风 · ${player.flowers.length} 花</span></div>
    </div>`;
    if (seat === YOU) return label;

    const tiles = player.hand ? [...player.hand].sort((a, b) => a - b) : Array(player.count).fill(null);
    const hand = tiles.map(tile => tileMarkup(tile, view.gold, { compact: true })).join("");
    const melds = player.melds.map(meld => meldMarkup(meld, view.gold)).join("");
    return `${label}<div class="opponent-tiles" aria-label="${player.count} 张手牌">${hand}</div>
      ${melds ? `<div class="opponent-melds">${melds}</div>` : ""}`;
  }

  function renderHand(view, options, focusTile) {
    const container = $("hand");
    const scroll = container.scrollLeft;
    const playable = options.some(move => move.type === "discard");
    const tiles = [...view.players[YOU].hand];
    const drawn = view.drawn !== null;
    const newest = drawn ? tiles.pop() : null;
    tiles.sort((a, b) => a - b);
    if (drawn) tiles.push(newest);

    container.innerHTML = tiles.map((tile, index) => tileMarkup(tile, view.gold, {
      index: playable ? index : undefined,
      picked: playable && selected?.index === index,
      drawn: drawn && index === tiles.length - 1,
    })).join("");
    container.scrollLeft = scroll;
    if (focusTile !== undefined) container.querySelector(`[data-index="${focusTile}"]`)?.focus({ preventScroll: true });
  }

  function renderStatus(view, options) {
    const discard = options.some(move => move.type === "discard");
    let title;
    let detail;
    if (view.result) {
      title = resultTitle(view.result);
      detail = "查看积分明细，或继续下一局";
    } else if (view.phase === "opening") {
      title = view.opening === "three" ? "开局三金倒" : "开局抢金";
      detail = options.length ? "请选择是否胡牌" : "等待开局判定";
    } else if (view.phase === "reaction") {
      const { seat, tile } = view.lastDiscard;
      title = options.length ? "请选择操作" : "等待其他玩家";
      detail = `${NAMES[seat]}打出 ${tileName(tile)}`;
    } else if (discard) {
      title = "轮到你出牌";
      if (selected) detail = `已选 ${tileName(selected.tile)}，再次点击可打出`;
      else detail = view.drawn === null ? "请选择一张手牌" : `摸到 ${tileName(view.drawn)} · 请选择出牌`;
    } else {
      title = `轮到${NAMES[view.current]}出牌`;
      detail = `${direction(view.current, view)}风 · AI 正在行牌`;
    }
    $("status-title").textContent = title;
    $("status-detail").textContent = detail;
    $("turn-icon").classList.toggle("ready", options.length > 0);

    const buttons = options.filter(move => move.type !== "discard").map(move => {
      let label = MELD_NAMES[move.type] || "过";
      if (move.type === "win") {
        label = move.kind === "self" || move.kind === "discard" ? "胡" : WIN_NAMES[move.kind];
        if (move.tile !== undefined) label += ` · 换 ${tileName(move.tile)}`;
      } else if (move.type === "chow") {
        label += ` · ${[...move.tiles, move.tile].sort((a, b) => a - b).map(tileName).join("")}`;
      } else if (move.type === "addedKong" || move.type === "concealedKong") {
        label += ` · ${tileName(move.tile)}`;
      }
      const variant = move.type === "win" ? "button-win" : "button-outline";
      return `<button type="button" class="button ${variant}" data-action="${move.id}">${label}</button>`;
    });
    if (discard) {
      if (selected) buttons.push('<button type="button" class="button button-outline" data-command="clear">取消选择</button>');
      buttons.push(`<button type="button" class="button button-primary" data-command="discard"${selected ? "" : " disabled"}>出牌</button>`);
    }
    if (view.result) {
      buttons.push('<button type="button" class="button button-outline" data-command="result">结算明细</button>');
      buttons.push('<button type="button" class="button button-primary" data-command="next">下一局</button>');
    }
    $("actions").innerHTML = buttons.join("");
  }

  function recordLatest(view) {
    const event = view.latest;
    if (event === lastEvent) return;
    lastEvent = event;
    const { seat, type, tile } = event;
    let line;
    if (type === "start") line = `第 ${view.round} 局开牌 · ${NAMES[seat]}坐庄`;
    else if (type === "discard") line = `${NAMES[seat]}打出 ${tileName(tile)}`;
    else line = `${NAMES[seat]}${MELD_NAMES[type]}${tile === null ? "" : ` ${tileName(tile)}`}`;
    history.unshift(line);
    history = history.slice(0, 5);
  }

  function render(view, options) {
    $("round-number").textContent = String(view.round).padStart(2, "0");
    $("remaining").textContent = view.remaining;
    $("gold-display").innerHTML = `<span>本局金牌</span>${tileMarkup(view.gold, view.gold)}<span>${tileName(view.gold)}${view.indicator === null ? " · 已抢" : ""}</span>`;
    for (const seat of SEATS) {
      const active = view.phase === "turn" && view.current === seat;
      $(`seat-${seat}`).innerHTML = seatMarkup(seat, view, active);
      const { river } = view.players[seat];
      $(`river-${seat}`).innerHTML = river.map((tile, index) => tileMarkup(tile, view.gold, {
        last: view.lastDiscard?.seat === seat && index === river.length - 1,
      })).join("");
    }
    $("player-melds").innerHTML = view.players[YOU].melds.map(meld => meldMarkup(meld, view.gold)).join("");
    renderHand(view, options);
    renderStatus(view, options);

    $("scores").innerHTML = SEATS.map(seat => `<div class="score-row">
      <span class="score-avatar avatar-${seat}" aria-hidden="true">${AVATARS[seat]}</span>
      <span><span class="score-name">${NAMES[seat]}${seat === view.dealer ? " · 庄" : ""}</span>
      <span class="score-label">${LOCATIONS[seat]}${seat === YOU ? "" : " · AI"}</span></span>
      <span><strong class="score-value ${scoreClass(view.scores[seat])}">${scoreLabel(view.scores[seat])}</strong><span class="score-unit"> 分</span></span>
    </div>`).join("");
    recordLatest(view);
    $("feed").innerHTML = history.map(line => `<li>${line}</li>`).join("");
  }

  function showResult(view) {
    const result = view.result;
    if (!result || rules.open || reset.open || resultDialog.open) return;
    shownResult = result;
    $("result-round").textContent = `第 ${view.round} 局 · 结算`;
    $("result-title").textContent = resultTitle(result);
    let breakdown = "<p>已到保留牌尾，本局积分不变。</p>";
    if (result.winner !== null) {
      const { hand, melds } = view.players[result.winner];
      const payers = result.payers.map(seat => NAMES[seat]).join("、");
      breakdown = `<div class="result-tiles">${[...hand].sort((a, b) => a - b)
        .map(tile => tileMarkup(tile, view.gold)).join("")}${melds.map(meld => meldMarkup(meld, view.gold)).join("")}</div>
        <p>底分 3 ＋ 花 ${result.flowerCount} ＋ 金 ${result.goldCount} ＋ 明杠及补杠 ${result.exposedKongs}
        ＋ 暗杠 ${result.concealedKongs} × 2 = ${result.base} 分</p>
        <p>${result.base} × ${result.multiplier} = 每家应付 ${result.perPayer} 分。付款方为${payers}。</p>`;
    }
    $("result-body").innerHTML = `${breakdown}<div class="result-total">
      <small>牌手</small><small>本局</small><small>累计</small>
      ${SEATS.map(seat => `<span>${NAMES[seat]}</span><strong class="${scoreClass(result.deltas[seat])}">${scoreLabel(result.deltas[seat])}</strong>
      <strong class="${scoreClass(view.scores[seat])}">${scoreLabel(view.scores[seat])}</strong>`).join("")}
    </div>`;
    resultDialog.showModal();
  }

  function sync() {
    clearTimeout(timer);
    const view = game.view(YOU);
    render(view, game.actions(YOU));
    if (view.result) {
      if (shownResult !== view.result) showResult(view);
      return;
    }
    if (rules.open || reset.open) return;
    const seat = SEATS.slice(1).find(other => game.actions(other).length);
    if (seat === undefined) return;
    timer = setTimeout(() => {
      const actions = game.actions(seat);
      const move = chooseAction(game.view(seat), actions);
      if (move) game.act(seat, move.id);
      sync();
    }, view.phase === "turn" ? 460 : 240);
  }

  function start() {
    game = new Game();
    selected = null;
    history = [];
    lastEvent = null;
    shownResult = null;
    $("hand").scrollLeft = 0;
    sync();
  }

  function humanAction(id) {
    if (!game.act(YOU, id)) return;
    selected = null;
    sync();
  }

  function discardSelected() {
    if (!selected) return;
    const discard = game.actions(YOU).find(move => move.type === "discard" && move.tile === selected.tile);
    if (discard) humanAction(discard.id);
  }

  function nextRound() {
    if (!game.nextRound()) return;
    resultDialog.close();
    selected = null;
    history = [];
    $("hand").scrollLeft = 0;
    sync();
  }

  function selectTile(selection, focusIndex) {
    selected = selection;
    const view = game.view(YOU);
    const options = game.actions(YOU);
    renderHand(view, options, focusIndex);
    renderStatus(view, options);
  }

  $("hand").addEventListener("click", event => {
    const button = event.target.closest("button[data-index]");
    if (!button) return;
    const { index, tile } = button.dataset;
    if (selected?.index === Number(index)) {
      discardSelected();
      return;
    }
    selectTile({ index: Number(index), tile: Number(tile) }, Number(index));
  });

  $("actions").addEventListener("click", event => {
    const button = event.target.closest("button");
    if (!button) return;
    const { action, command } = button.dataset;
    if (action) humanAction(action);
    if (command === "discard") discardSelected();
    if (command === "clear") selectTile(null, selected?.index);
    if (command === "result") showResult(game.view(YOU));
    if (command === "next") nextRound();
  });

  $("open-rules").addEventListener("click", () => {
    rules.showModal();
    clearTimeout(timer);
  });
  $("open-reset").addEventListener("click", () => {
    reset.showModal();
    clearTimeout(timer);
  });
  rules.addEventListener("close", sync);
  reset.addEventListener("close", sync);
  $("confirm-reset").addEventListener("click", () => {
    reset.close();
    start();
  });
  $("result-next").addEventListener("click", nextRound);

  start();
})();
