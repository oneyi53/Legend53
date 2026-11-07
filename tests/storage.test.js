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
  assert.equal(save.version,2);
  assert.equal(save.classId,"mage");
  assert.equal(save.level,3);
  const game=new Game();
  assert.equal(game.classId,"mage");
  assert.equal(game.level,3);
  assert.equal(game.enemies.length,8);
});

test("version 2 saves restore enemy health and uncollected drops",()=>{
  values.set(KEY,JSON.stringify({
    version:2,classId:"warrior",level:2,exp:10,gold:50,potions:2,hp:90,x:450,y:700,
    enemies:[{id:"forest_beast",name:"森林劫掠者",x:480,y:710,hp:7,hpMax:54,attack:7,defense:1,speed:48,xp:22,gold:[5,12],alive:true,attackTimer:.4,phase:1.2}],
    drops:[{x:460,y:705,type:"gold",amount:9,label:"金币 +9"}]
  }));
  const game=new Game();
  assert.equal(game.enemies.length,1);
  assert.equal(game.enemies[0].hp,7);
  assert.equal(game.drops.length,1);
  assert.equal(game.drops[0].amount,9);
  assert.equal(game.save(),undefined);
  const saved=JSON.parse(values.get(KEY));
  assert.equal(saved.version,2);
  assert.equal(saved.enemies[0].hp,7);
  assert.equal(saved.drops[0].amount,9);
});
