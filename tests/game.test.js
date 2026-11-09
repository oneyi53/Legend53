import test from "node:test";
import assert from "node:assert/strict";
import { Game } from "../web/js/game.js";

globalThis.localStorage={getItem:()=>null,setItem:()=>{}};

function freshGame(){
  const game=new Game();
  game.player.x=450;game.player.y=500;game.enemies=[];
  return game;
}
test("new game starts as an offline warrior",()=>{
  const game=freshGame();
  assert.equal(game.classId,"warrior");
  assert.equal(game.level,1);
  assert.equal(game.maxHp,135);
  assert.equal(game.gold,100);
});
test("class switching preserves the health ratio",()=>{
  const game=freshGame();game.hp=game.maxHp/2;
  assert.equal(game.switchClass("mage"),true);
  assert.equal(game.classId,"mage");
  assert.equal(game.hp,44);
  assert.equal(game.switchClass("unknown"),false);
});
test("basic attack defeats a nearby enemy and awards experience",()=>{
  const game=freshGame();
  const enemy=game.makeEnemy({id:"test",name:"测试怪",hp:1,attack:1,defense:0,speed:0,xp:20,gold:[1,1]},450,540);
  game.enemies=[enemy];game.target=enemy;game.basicAttack();
  assert.equal(enemy.alive,false);
  assert.equal(game.kills,1);
  assert.equal(game.exp,20);
});
test("quest progress counts only kills after accepting the quest",()=>{
  const game=freshGame();
  const enemy=game.makeEnemy({id:"test",name:"测试怪",hp:1,attack:1,defense:0,speed:0,xp:1,gold:[1,1]},450,540);
  game.enemies=[enemy];game.target=enemy;game.basicAttack();
  assert.equal(game.questKills,0);
  game.player.y=260;game.interactNpc("village_elder");game.acceptQuest();game.player.y=500;
  const next=game.makeEnemy({id:"forest_beast",name:"森林劫掠者",hp:1,attack:1,defense:0,speed:0,xp:1,gold:[1,1]},450,540);
  game.enemies=[next];game.target=next;game.player.attackTimer=0;game.basicAttack();
  assert.equal(game.questKills,1);
});
test("skill cooldown and potion consumption are applied",()=>{
  const game=freshGame();game.potions=1;game.hp=50;
  game.usePotion();
  assert.equal(game.potions,0);
  assert.ok(game.hp>50);
  game.castSkill();
  assert.ok(game.player.skillTimer>0);
});
test("skill points are awarded on level up and can improve the skill",()=>{
  const game=freshGame();game.exp=100;game.gainExp(1);
  assert.equal(game.level,2);
  assert.equal(game.skillPoints,1);
  assert.equal(game.upgradeSkill(),true);
  assert.equal(game.skillLevel,2);
  assert.equal(game.skillPoints,0);
});

test("equipment defense reduces incoming damage",()=>{
  const game=freshGame();
  game.equipment={armor:{id:"test_armor",name:"测试护甲",slot:"armor",defense:2}};
  game.hp=game.maxHp;
  game.takeDamage(10);
  assert.equal(game.hp,game.maxHp-5);
});

import {TREE_PLACEMENTS,isBlockedByTree,findPath,hasLineOfSight} from "../web/js/world.js";

test("world collision data matches deterministic visible tree placements",()=>{
  assert.equal(TREE_PLACEMENTS.length,38);
  const tree=TREE_PLACEMENTS[0];
  assert.equal(isBlockedByTree(tree.x,tree.y+3),true);
  assert.equal(isBlockedByTree(450,330),false);
});

test("player cannot pass through a tree trunk but can slide along it",()=>{
  const game=freshGame();
  const tree=TREE_PLACEMENTS[0];
  game.player.x=tree.x-30;
  game.player.y=tree.y+3;
  const beforeY=game.player.y;
  game.movePlayer(25,0);
  assert.equal(game.player.x,tree.x-30);
  game.movePlayer(25,10);
  assert.ok(game.player.y>beforeY);
  assert.equal(isBlockedByTree(game.player.x,game.player.y),false);
});


test("A* routes around tree trunks without cutting diagonally through them",()=>{
  const tree=TREE_PLACEMENTS[1];
  const path=findPath(tree.x-90,tree.y+3,tree.x+90,tree.y+3,12);
  assert.ok(Array.isArray(path)&&path.length>0);
  let x=tree.x-90,y=tree.y+3;
  for(const point of path){
    const distance=Math.hypot(point.x-x,point.y-y);
    const steps=Math.max(1,Math.ceil(distance/5));
    for(let i=1;i<=steps;i++){
      const sx=x+(point.x-x)*i/steps,sy=y+(point.y-y)*i/steps;
      assert.equal(isBlockedByTree(sx,sy,12),false);
    }
    x=point.x;y=point.y;
  }
  assert.ok(Math.abs(x-(tree.x+90))<=20);
});

test("enemy pursuit follows a collision-safe route around trees",()=>{
  const game=freshGame();
  const tree=TREE_PLACEMENTS[1];
  const enemy=game.makeEnemy({id:"test",name:"测试怪",hp:10,attack:1,defense:0,speed:100,xp:1,gold:[1,1]},tree.x-90,tree.y+3);
  game.enemies=[enemy];
  for(let i=0;i<30;i++)game.moveEnemyToward(enemy,tree.x+90,tree.y+3,100,.1);
  assert.ok(enemy.x>tree.x+20);
  assert.equal(isBlockedByTree(enemy.x,enemy.y,12),false);
});


test("tree trunks block direct attacks but clear paths remain visible",()=>{
  const tree=TREE_PLACEMENTS[1];
  assert.equal(hasLineOfSight(tree.x-80,tree.y+3,tree.x+80,tree.y+3),false);
  assert.equal(hasLineOfSight(450,330,500,330),true);
});

test("basic attacks cannot hit an enemy through a tree",()=>{
  const game=freshGame();
  const tree=TREE_PLACEMENTS[1];
  game.player.x=tree.x-80;game.player.y=tree.y+3;
  const enemy=game.makeEnemy({id:"test",name:"测试怪",hp:100,attack:1,defense:0,speed:0,xp:1,gold:[1,1]},tree.x+80,tree.y+3);
  game.enemies=[enemy];game.target=enemy;game.basicAttack();
  assert.equal(enemy.hp,100);
  assert.equal(game.player.attackTimer,0);
});

test("auto combat navigates toward a target hidden behind a tree",()=>{
  const game=freshGame();
  const tree=TREE_PLACEMENTS[1];
  game.player.x=tree.x-80;game.player.y=tree.y+3;
  const enemy=game.makeEnemy({id:"test",name:"测试怪",hp:100,attack:1,defense:0,speed:0,xp:1,gold:[1,1]},tree.x+80,tree.y+3);
  game.enemies=[enemy];game.target=enemy;game.auto=true;
  const before=game.player.x;
  game.update(.1,{getDirection:()=>({x:0,y:0})});
  assert.ok(game.player.x!==before||game.player.y!==tree.y+3);
  assert.equal(isBlockedByTree(game.player.x,game.player.y,12),false);
});
