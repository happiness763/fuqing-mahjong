# Fuqing Mahjong Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkboxes for tracking.

**Goal:** Deliver a complete offline browser game for one human and three AI opponents.

**Architecture:** Separate hand evaluation and round transitions from AI decisions and DOM rendering. Load classic scripts so the entry point works directly from disk, with a conditional CommonJS export for dependency-free tests.

**Tech Stack:** HTML, CSS, JavaScript, Node's built-in test runner, local browser verification.

**Spec:** `docs/superpowers/specs/2026-11-10-fuqing-mahjong-design.md`

## Global Constraints

144 tiles, 36 flowers, 17/16 starting hand sizes, 18 reserved tiles. Chinese interface, offline assets, zero-sum table points, hidden opponent information, one legal action engine for all seats.

## Review Focus

- Identical gold tiles are wild in hand and are ineligible for open melds.
- Winning with gold must consider all legal decompositions and pair assignments.
- Simultaneous claims and opening wins must resolve by priority and seating order.
- A final live flower or kong draw must complete or result in a clean draw.
- A complete round and a new round preserve all tiles and zero-sum scores.

## 1. Evaluate and settle hands

- [x] Add red tests for the deck, multiple wildcard decompositions, gold pair, idle gold and exact zero-sum payments in `test/mahjong.test.cjs`.
- [x] Implement `makeWall`, `isWinningHand`, `isIdleGold`, `scoreWin` and shared tile metadata in `src/mahjong.js`.
- [x] Run `node --test test/mahjong.test.cjs` and confirm the evaluator tests pass.

## 2. Drive the round and AI

- [x] Add red tests for dealing, flower and reserve behavior, contested actions, gold restrictions, opening claims, kongs and dealer changes.
- [x] Implement `Game`, `Game.actions(seat)`, `Game.act(seat, id)`, `Game.nextRound()` and `Game.view(seat)` in `src/mahjong.js`. Distinguish opening, turn, reaction and result states.
- [x] Implement `chooseAction(view, actions)` in `src/ai.js`, using public counts and the current player's hand to retain connected shapes and improve waits.
- [x] Run the full suite and play seeded AI rounds to termination, checking tile conservation, score totals and round transitions.

## 3. Build and verify the offline table

- [x] Create `index.html`, `src/styles.css`, and `src/app.js` with a responsive table, player controls, rules and round results.
- [x] Load the entry through `file://` in a browser and check desktop and mobile rendering, human selection and discard, AI turns, rule panel, settlement and continuing play.
- [x] Run `node --test` and report verified behavior and the local entry point.
