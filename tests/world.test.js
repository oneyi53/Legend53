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

test("only the current region spawns enemies and respects its active cap",()=>{
  const game=new Game();
  assert.equal(game.region,"village");
  assert.equal(game.enemies.length,0);
  game.player.y=450;
  game.updateRegion();
  assert.equal(game.enemies.length,3);
  assert.ok(game.enemies.every(enemy=>enemy.regionId==="entrance"&&enemy.active));
  game.player.y=650;
  game.updateRegion();
  assert.equal(game.enemies.filter(enemy=>enemy.active).length,3);
  assert.ok(game.enemies.filter(enemy=>enemy.active).every(enemy=>enemy.regionId==="deepwood"));
});

test("inactive region enemies pause and resume without losing their state",()=>{
  const game=new Game();
  game.player.y=450;game.updateRegion();
  const enemy=game.enemies.find(item=>item.id==="forest_beast");
  enemy.hp=13;
  enemy.x+=30;
  game.player.y=650;game.updateRegion();
  const pausedX=enemy.x;
  const pausedTimer=enemy.respawnTimer;
  game.update(5,input);
  assert.equal(enemy.active,false);
  assert.equal(enemy.x,pausedX);
  assert.equal(enemy.respawnTimer,pausedTimer);
  game.player.y=450;game.updateRegion();
  assert.equal(enemy.active,true);
  assert.equal(enemy.hp,13);
  assert.equal(enemy.x,pausedX);
});

test("defeated monsters respawn at their original spawn point after active time",()=>{
  const game=new Game();
  game.player.y=450;game.updateRegion();
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
  game.player.y=450;game.updateRegion();
  game.acceptQuest();
  const wolf=game.enemies.find(enemy=>enemy.id==="thorn_wolf");
  const raider=game.enemies.find(enemy=>enemy.id==="forest_beast");
  game.defeat(wolf);
  assert.equal(game.questKills,0);
  game.defeat(raider);
  assert.equal(game.questKills,1);
});

test("entering the altar creates a single boss and only after level unlock",()=>{
  const game=new Game();
  game.player.y=1200;
  game.updateRegion();
  assert.equal(game.region,"altar");
  assert.equal(game.enemies.filter(enemy=>enemy.boss).length,1);
  game.player.y=1000;game.updateRegion();
  game.player.y=1200;game.updateRegion();
  assert.equal(game.enemies.filter(enemy=>enemy.boss).length,1);
});

test("movement cannot cross a region gate before reaching its level",()=>{
  const game=new Game();
  game.player.y=550;
  game.movePlayer(0,30);
  assert.equal(game.player.y,559);
  game.level=3;
  game.movePlayer(0,40);
  assert.equal(game.player.y,599);
});
