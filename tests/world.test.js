import test,{beforeEach,afterEach} from "node:test";
import assert from "node:assert/strict";
import {Game} from "../web/js/game.js";

let values;
beforeEach(()=>{
  values=new Map();
  globalThis.localStorage={
    getItem:key=>values.has(key)?values.get(key):null,
    setItem:(key,value)=>values.set(key,String(value))
  };
});
afterEach(()=>{delete globalThis.localStorage});

const input={getDirection:()=>({x:0,y:0})};

test("world creates stable spawn points assigned to map regions",()=>{
  const game=new Game();
  assert.equal(game.enemies.length,8);
  assert.equal(new Set(game.enemies.map(enemy=>enemy.spawnId)).size,8);
  assert.equal(game.enemies.find(enemy=>enemy.spawnId==="deepwood_wolf_1").regionId,"deepwood");
  assert.equal(game.enemies.find(enemy=>enemy.spawnId==="ruins_elite_1").elite,true);
});

test("defeated monsters respawn at their original spawn point",()=>{
  const game=new Game();
  const enemy=game.enemies.find(item=>item.id==="forest_beast");
  const home={x:enemy.homeX,y:enemy.homeY};
  enemy.x+=80;enemy.y+=60;
  game.defeat(enemy);
  assert.equal(enemy.alive,false);
  assert.equal(enemy.respawnTimer,24);
  game.update(24,input);
  assert.equal(enemy.alive,true);
  assert.equal(enemy.hp,enemy.hpMax);
  assert.equal(enemy.x,home.x);
  assert.equal(enemy.y,home.y);
});

test("main quest counts only forest raiders, not wolves or elite guards",()=>{
  const game=new Game();
  game.acceptQuest();
  const wolf=game.enemies.find(enemy=>enemy.id==="thorn_wolf");
  const guard=game.enemies.find(enemy=>enemy.id==="ruin_guard");
  const raider=game.enemies.find(enemy=>enemy.id==="forest_beast");
  game.defeat(wolf);
  game.defeat(guard);
  assert.equal(game.questKills,0);
  game.defeat(raider);
  assert.equal(game.questKills,1);
});

test("entering the altar creates only one boss spawn",()=>{
  const game=new Game();
  game.player.y=1200;
  game.updateRegion();
  assert.equal(game.enemies.filter(enemy=>enemy.boss).length,1);
  const boss=game.enemies.find(enemy=>enemy.boss);
  game.defeat(boss);
  game.player.y=1000;
  game.updateRegion();
  game.player.y=1200;
  game.updateRegion();
  assert.equal(game.enemies.filter(enemy=>enemy.boss).length,1);
});
