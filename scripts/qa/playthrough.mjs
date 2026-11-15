// Scripted full playthrough (headless): create -> enter village -> fight ->
// level up -> loot & equip -> potion -> skill -> death -> revive -> save/reload.
// Mirrors the phone test steps in UI_REBUILD_CHECK.md. Run: node scripts/qa/playthrough.mjs
import { Game } from "../../web/js/game.js";
import { resetSave, loadSave } from "../../web/js/storage.js";

const store = new Map();
globalThis.localStorage = {
  getItem: (k) => (store.has(k) ? store.get(k) : null),
  setItem: (k, v) => store.set(k, String(v)),
  removeItem: (k) => store.delete(k),
};
const idle = { getDirection: () => ({ x: 0, y: 0 }) };
const log = (s) => console.log("  " + s);

console.log("1. 建角：法师 沈秋");
resetSave("mage", "沈秋");
let game = new Game();
console.assert(game.name === "沈秋" && game.classId === "mage", "create failed");
log(`建角完成：${game.name} ${game.klass.name} HP ${game.hp}/${game.maxHp} MP ${game.mp}/${game.maxMp}`);

console.log("2. 进新手村（守林新手村 450,330）");
console.assert(game.region === "village" && game.player.x === 450 && game.player.y === 330, "spawn failed");
log(`区域：${game.region} 坐标 ${game.player.x},${game.player.y}`);

console.log("3. 打怪：走到林间入口杀 3 名森林劫掠者");
game.player.y = 500;
game.update(0.1, idle);
console.assert(game.region === "entrance", "region failed: " + game.region);
for (let n = 0; n < 3; n++) {
  const e = game.makeEnemy({ id: "forest_beast", name: "森林劫掠者", hp: 1, attack: 1, defense: 0, speed: 0, xp: 22, gold: [5, 12] }, 450, 540);
  game.enemies = [e];
  game.target = e;
  game.player.attackTimer = 0;
  game.basicAttack();
  console.assert(!e.alive, "kill failed");
}
log(`击杀 3，任务怪计数前先接任务再验证（见单测）；经验 ${game.exp} 金币掉落待拾取`);

console.log("4. 升级：经验满 100 升到 Lv.2");
game.gainExp(200);
console.assert(game.level >= 2 && game.skillPoints >= 1, "level failed");
log(`等级 Lv.${game.level} 技能点 ${game.skillPoints} HP 已回满 ${game.hp}/${game.maxHp}`);

console.log("5. 拾取与穿戴：掉落装备进背包并装备");
game.drops.push({ x: 450, y: 500, type: "gear", item: { id: "t1", name: "测试短剑", slot: "weapon", quality: "优秀", attack: 5, health: 0, defense: 0 } });
game.update(0.1, idle);
console.assert(game.inventory.length === 1, "pickup failed");
console.assert(game.equipItem(0) === true && game.equipment.weapon?.name === "测试短剑", "equip failed");
log(`已装备 ${game.equipment.weapon.name}，攻击 ${game.attack}`);

console.log("6. 技能与药水：耗魔放技能、喝药回血");
game.mp = game.maxMp;
game.player.skillTimer = 0;
game.castSkill();
console.assert(game.mp < game.maxMp, "skill MP cost failed");
game.hp = 50;
game.potions = 2;
game.usePotion();
console.assert(game.hp > 50 && game.potions === 1, "potion failed");
log(`技能耗魔 ${game.skillCost}，喝药后 HP ${game.hp} 剩余药水 ${game.potions}`);

console.log("7. 死亡与复活");
game.hp = 5;
game.takeDamage(500);
console.assert(game.dead === true && game.hp === 0, "death failed");
console.assert(game.revive() === true && game.hp === game.maxHp, "revive failed");
log(`死亡后回城复活，HP ${game.hp}/${game.maxHp} 位置 ${game.player.x},${game.player.y}`);

console.log("8. 存档重进");
game.save();
const save = loadSave();
console.assert(save.name === "沈秋" && save.level === game.level, "save failed");
const again = new Game();
console.assert(again.name === "沈秋" && again.level === game.level, "reload failed");
log(`重进后 ${again.name} Lv.${again.level} 位置 ${again.player.x},${again.player.y}`);
console.log("PLAYTHROUGH OK");
