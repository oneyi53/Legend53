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
  game.interactNpc("village_elder");game.acceptQuest();
  game.player.y=450;game.updateRegion();
  const wolf=game.enemies.find(enemy=>enemy.id==="thorn_wolf");
  const raider=game.enemies.find(enemy=>enemy.id==="forest_beast");
  game.defeat(wolf);
  assert.equal(game.questKills,0);
  game.defeat(raider);
  assert.equal(game.questKills,1);
});

test("entering the altar creates a single boss and only after level unlock",()=>{
  const game=new Game();
  game.level=8;
  game.movePlayer(0,870);
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

test("loading an over-level saved position clamps it to the highest unlocked region",()=>{
  values.set("hero-world-html5-save-v1",JSON.stringify({
    version:2,classId:"warrior",level:1,x:450,y:1200,enemies:[],drops:[]
  }));
  const game=new Game();
  assert.equal(game.player.y,559);
  assert.equal(game.region,"entrance");
  assert.ok(game.enemies.every(enemy=>enemy.regionId==="entrance"));
});

test("changing regions drops targets from the previous region",()=>{
  const game=new Game();
  game.player.y=450;game.updateRegion();
  game.target=game.enemies.find(enemy=>enemy.alive);
  assert.ok(game.target);
  game.player.y=650;game.updateRegion();
  assert.equal(game.target,null);
  assert.ok(game.enemies.filter(enemy=>enemy.active).every(enemy=>enemy.regionId==="deepwood"));
});

test("main quest requires speaking to the village elder before accepting",()=>{
  const game=new Game();
  assert.equal(game.acceptQuest(),false);
  assert.equal(game.questAccepted,false);
  assert.equal(game.interactNpc("village_elder"),true);
  assert.equal(game.acceptQuest(),true);
  assert.equal(game.questAccepted,true);
});
test("quest can only be claimed after three exact target kills and returning to elder",()=>{
  const game=new Game();
  game.interactNpc("village_elder");game.acceptQuest();
  game.player.y=450;game.updateRegion();
  const wolf=game.enemies.find(enemy=>enemy.id==="thorn_wolf");
  const raider=game.enemies.find(enemy=>enemy.id==="forest_beast");
  game.defeat(wolf);
  assert.equal(game.questKills,0);
  for(let i=0;i<3;i++)game.defeat({...raider,alive:true});
  assert.equal(game.questKills,3);
  assert.equal(game.claimQuest(),false);
  game.player.y=260;game.updateRegion();game.interactNpc("village_elder");
  const goldBefore=game.gold;
  assert.equal(game.claimQuest(),true);
  assert.equal(game.questClaimed,true);
  assert.equal(game.gold,goldBefore+60);
  assert.ok(game.inventory.some(item=>item.id==="quest_badge"));
  assert.equal(game.claimQuest(),false);
});
test("quest progress is capped at its target and survives save reload",()=>{
  const game=new Game();
  game.interactNpc("village_elder");game.acceptQuest();
  game.player.y=450;game.updateRegion();
  const raider=game.enemies.find(enemy=>enemy.id==="forest_beast");
  for(let i=0;i<5;i++)game.defeat({...raider,alive:true});
  assert.equal(game.questKills,3);
  game.save();
  const restored=new Game();
  assert.equal(restored.questAccepted,true);
  assert.equal(restored.questKills,3);
});

test("blacksmith shop requires proximity and deducts gold for valid purchases",()=>{
  const game=new Game();
  assert.equal(game.buyShopItem("iron_sword"),false);
  game.player.x=310;game.player.y=185;
  assert.equal(game.interactNpc("village_smith"),true);
  game.gold=200;
  const before=game.gold;
  assert.equal(game.buyShopItem("iron_sword"),true);
  assert.equal(game.gold,before-120);
  assert.ok(game.inventory.some(item=>item.id==="iron_sword"));
});
test("shop rejects insufficient funds and does not mutate inventory",()=>{
  const game=new Game();
  game.player.x=310;game.player.y=185;game.interactNpc("village_smith");
  game.gold=10;
  const count=game.inventory.length;
  assert.equal(game.buyShopItem("leather_armor"),false);
  assert.equal(game.gold,10);
  assert.equal(game.inventory.length,count);
});
test("potion purchase increments potion stock and persists through save",()=>{
  const game=new Game();
  game.player.x=310;game.player.y=185;game.interactNpc("village_smith");
  const before=game.potions;
  assert.equal(game.buyShopItem("small_potion"),true);
  assert.equal(game.potions,before+1);
  game.save();
  const restored=new Game();
  assert.equal(restored.potions,before+1);
});
