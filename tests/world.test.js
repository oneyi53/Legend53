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
  assert.equal(game.enemies.filter(enemy=>enemy.active).length,4);
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

test("deepwood quest unlocks only after first quest and level three",()=>{
  const game=new Game();game.player.y=260;game.interactNpc("village_elder");
  assert.equal(game.acceptDeepwoodQuest(),false);
  game.questClaimed=true;game.level=2;
  assert.equal(game.acceptDeepwoodQuest(),false);
  game.level=3;assert.equal(game.acceptDeepwoodQuest(),true);
});
test("deepwood quest requires entering region, defeating exact elite and collecting its material",()=>{
  const game=new Game();game.player.y=260;game.questClaimed=true;game.level=3;game.interactNpc("village_elder");game.acceptDeepwoodQuest();
  game.player.y=600;game.updateRegion();assert.equal(game.deepwoodEntered,true);
  const wolf=game.enemies.find(e=>e.id==="thorn_wolf");
  const elite=game.enemies.find(e=>e.id==="woodland_chief");
  game.defeat(wolf);assert.equal(game.deepwoodEliteKills,0);
  game.defeat(elite);assert.equal(game.deepwoodEliteKills,1);
  assert.equal(game.questMaterials,0);
  const material=game.drops.find(d=>d.type==="quest_item");assert.ok(material);
  game.player.x=material.x;game.player.y=material.y;game.update(0.01,input);
  assert.equal(game.questMaterials,3);
});
test("deepwood quest reward requires returning to elder and can only be claimed once",()=>{
  const game=new Game();game.player.y=260;game.questClaimed=true;game.level=3;game.interactNpc("village_elder");game.acceptDeepwoodQuest();
  game.deepwoodEntered=true;game.deepwoodEliteKills=1;game.questMaterials=3;
  game.player.y=650;game.updateRegion();assert.equal(game.claimDeepwoodQuest(),false);
  game.player.y=260;game.updateRegion();game.interactNpc("village_elder");
  const gold=game.gold;assert.equal(game.claimDeepwoodQuest(),true);assert.equal(game.gold,gold+160);
  assert.ok(game.inventory.some(item=>item.id==="deepwood_guardian_armor"));
  assert.equal(game.claimDeepwoodQuest(),false);
});
test("deepwood quest progress persists in version four save",()=>{
  const game=new Game();game.deepwoodQuestAccepted=true;game.deepwoodEntered=true;game.deepwoodEliteKills=1;game.questMaterials=2;game.save();
  const restored=new Game();assert.equal(restored.deepwoodQuestAccepted,true);assert.equal(restored.deepwoodEntered,true);assert.equal(restored.deepwoodEliteKills,1);assert.equal(restored.questMaterials,2);
});
