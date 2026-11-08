import test,{beforeEach,afterEach} from "node:test";
import assert from "node:assert/strict";
import {Game} from "../web/js/game.js";
import {loadSave} from "../web/js/storage.js";

const KEY="hero-world-html5-save-v1";
let values;

beforeEach(()=>{
  values=new Map();
  globalThis.localStorage={
    getItem:key=>values.has(key)?values.get(key):null,
    setItem:(key,value)=>values.set(key,String(value))
  };
});
afterEach(()=>{delete globalThis.localStorage});

test("version 1 saves migrate without losing character progress",()=>{
  values.set(KEY,JSON.stringify({version:1,classId:"mage",level:3,exp:25,gold:80,x:410,y:620}));
  const save=loadSave();
  assert.equal(save.version,5);
  assert.equal(save.classId,"mage");
  assert.equal(save.level,3);
  const game=new Game();
  assert.equal(game.classId,"mage");
  assert.equal(game.level,3);
  assert.equal(game.enemies.filter(enemy=>enemy.active).length,4);
  assert.ok(game.enemies.every(enemy=>enemy.regionId==="deepwood"));
});

test("version 2 saves restore enemy health and uncollected drops",()=>{
  values.set(KEY,JSON.stringify({
    version:2,classId:"warrior",level:3,exp:10,gold:50,potions:2,hp:90,x:450,y:700,
    enemies:[{id:"forest_beast",name:"森林劫掠者",x:480,y:710,homeX:590,homeY:730,spawnId:"deepwood_beast_1",regionId:"deepwood",hp:7,hpMax:54,attack:7,defense:1,speed:48,xp:22,gold:[5,12],alive:true,attackTimer:.4,phase:1.2}],
    drops:[{x:460,y:705,type:"gold",amount:9,label:"金币 +9"}]
  }));
  const game=new Game();
  assert.equal(game.enemies.filter(enemy=>enemy.active).length,4);
  assert.equal(game.enemies.find(enemy=>enemy.spawnId==="deepwood_beast_1").hp,7);
  assert.equal(game.drops.length,1);
  assert.equal(game.drops[0].amount,9);
  game.save();
  const saved=JSON.parse(values.get(KEY));
  assert.equal(saved.version,5);
  assert.equal(saved.enemies.find(enemy=>enemy.spawnId==="deepwood_beast_1").hp,7);
  assert.equal(saved.drops[0].amount,9);
});

test("version 2 saves migrate to version 4 without losing quest progress",()=>{
  values.set(KEY,JSON.stringify({version:2,classId:"warrior",level:2,exp:15,gold:42,questAccepted:true,questKills:2,questClaimed:false,x:450,y:500}));
  const save=loadSave();
  assert.equal(save.version,5);
  assert.equal(save.questAccepted,true);
  assert.equal(save.questKills,2);
  const game=new Game();
  assert.equal(game.questKills,2);
  assert.equal(game.questAccepted,true);
});

test("version five save restores unique rolled equipment and its attributes",()=>{
  const game=new Game();game.inventory=[{id:"thorn_axe",instanceId:"gear-9",name:"荆棘战斧",slot:"weapon",quality:"史诗",attack:12,health:8,defense:1,affixes:["攻击强化"]}];
  game.equipItem(0);game.gearSequence=9;game.save();const restored=new Game();
  assert.equal(restored.equipment.weapon.instanceId,"gear-9");assert.equal(restored.equipment.weapon.attack,12);assert.equal(restored.equipment.weapon.affixes[0],"攻击强化");assert.equal(restored.gearSequence,9);
});