import test, { beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { Game } from "../web/js/game.js";
import { resetSave, loadSave } from "../web/js/storage.js";
import { ChatLog } from "../web/js/chat.js";

const KEY = "hero-world-html5-save-v1";
let values;

beforeEach(() => {
  values = new Map();
  globalThis.localStorage = {
    getItem: (key) => (values.has(key) ? values.get(key) : null),
    setItem: (key, value) => values.set(key, String(value)),
    removeItem: (key) => values.delete(key),
  };
});
afterEach(() => { delete globalThis.localStorage; });

function freshGame() {
  const game = new Game();
  game.player.x = 450;
  game.player.y = 500;
  game.enemies = [];
  return game;
}

test("new game has full MP and a saved name", () => {
  const game = freshGame();
  assert.equal(game.maxMp, 60);
  assert.equal(game.mp, 60);
  assert.equal(game.name, "无名旅者");
});

test("casting a skill costs MP and is refused when MP is short", () => {
  const game = freshGame();
  game.castSkill();
  assert.equal(game.mp, 60 - game.skillCost);
  assert.ok(game.player.skillTimer > 0);
  game.mp = 1;
  game.player.skillTimer = 0;
  game.castSkill();
  assert.equal(game.mp, 1);
  assert.equal(game.player.skillTimer, 0);
});

test("MP regenerates over time", () => {
  const game = freshGame();
  game.mp = 10;
  game.update(1, { getDirection: () => ({ x: 0, y: 0 }) });
  assert.ok(game.mp > 10);
});

test("lethal damage sets the dead state instead of instantly reviving", () => {
  const game = freshGame();
  game.hp = 5;
  game.takeDamage(500);
  assert.equal(game.hp, 0);
  assert.equal(game.dead, true);
  assert.equal(game.auto, false);
  // further damage and actions are ignored while dead
  game.takeDamage(500);
  game.manualAttack();
  assert.equal(game.dead, true);
  assert.equal(game.revive(), true);
  assert.equal(game.dead, false);
  assert.equal(game.hp, game.maxHp);
  assert.equal(game.player.x, 450);
  assert.equal(game.player.y, 330);
});

test("a dead save reloads revived at the village", () => {
  const game = freshGame();
  game.hp = 5;
  game.takeDamage(500);
  game.save();
  const reloaded = new Game();
  assert.equal(reloaded.dead, false);
  assert.equal(reloaded.hp, reloaded.maxHp);
  assert.equal(reloaded.player.x, 450);
});

test("return-to-village scroll moves the player home", () => {
  const game = freshGame();
  game.player.x = 600;
  game.player.y = 900;
  assert.equal(game.returnToVillage(), true);
  assert.equal(game.player.x, 450);
  assert.equal(game.player.y, 330);
});

test("creating a character resets the single save slot", () => {
  assert.equal(resetSave("mage", "沈秋"), true);
  const save = loadSave();
  assert.equal(save.classId, "mage");
  assert.equal(save.name, "沈秋");
  assert.equal(save.level, 1);
  const game = new Game();
  assert.equal(game.classId, "mage");
  assert.equal(game.name, "沈秋");
  assert.equal(game.maxMp, 150);
});

test("chat channels parse prefixes and gate world chat at Lv.8", () => {
  const lines = [];
  const logEl = { set innerHTML(v) { lines.push(v); }, get innerHTML() { return ""; }, scrollTop: 0, scrollHeight: 0 };
  const chat = new ChatLog(logEl);
  assert.equal(chat.send("!hello", 3, "沈秋"), false);
  chat.send("hello", 1, "沈秋");
  chat.send("!!集合", 1, "沈秋");
  chat.send("!~行会好", 1, "沈秋");
  chat.send("/阿强 在吗", 1, "沈秋");
  assert.equal(chat.send("!全服好", 8, "沈秋"), true);
  assert.ok(chat.messages.world.length >= 1);
  assert.ok(chat.messages.party.length >= 1);
  assert.ok(chat.messages.nearby.length >= 1);
});
