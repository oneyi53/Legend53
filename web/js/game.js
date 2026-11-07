import {CLASSES,REGIONS,ENEMIES,GEAR} from "./data.js";
import {loadSave,writeSave} from "./storage.js";
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const rand=(a,b)=>Math.floor(a+Math.random()*(b-a+1));
const SPAWN_POINTS=[
  {id:"entrance_beast_1",enemy:"forest_beast",x:380,y:500,region:"entrance"},
  {id:"entrance_beast_2",enemy:"forest_beast",x:520,y:540,region:"entrance"},
  {id:"deepwood_wolf_1",enemy:"thorn_wolf",x:310,y:680,region:"deepwood"},
  {id:"deepwood_beast_1",enemy:"forest_beast",x:590,y:730,region:"deepwood"},
  {id:"ruins_wolf_1",enemy:"thorn_wolf",x:400,y:900,region:"ruins"},
  {id:"ruins_elite_1",enemy:"ruin_guard",x:570,y:1020,region:"ruins"},
  {id:"ruins_beast_1",enemy:"forest_beast",x:330,y:1130,region:"ruins"},
  {id:"altar_wolf_1",enemy:"thorn_wolf",x:520,y:1260,region:"altar"}
];
export class Game{
  constructor(){
    const saved=loadSave();this.classId=saved?.classId||"warrior";this.level=saved?.level||1;this.exp=saved?.exp||0;this.gold=saved?.gold??100;this.potions=saved?.potions??3;this.inventory=saved?.inventory||[];this.equipment=saved?.equipment||{};
    this.hp=saved?.hp??this.maxHp;this.player={x:saved?.x??450,y:saved?.y??330,attackTimer:0,skillTimer:0,flash:0};
    this.kills=saved?.kills||0;this.questKills=saved?.questKills||0;this.skillPoints=saved?.skillPoints||0;this.questAccepted=saved?.questAccepted||false;this.questClaimed=saved?.questClaimed||false;this.skillLevel=saved?.skillLevel||1;this.region="village";this.auto=false;this.target=null;this.drops=[];this.effects=[];this.damageTexts=[];this.enemies=[];this.clock=0;this.autosaveTimer=0;this.notice="";this.noticeTime=0;this.onChange=()=>{};
    const restoredEnemies=Array.isArray(saved?.enemies)?saved.enemies.filter(e=>e&&typeof e.id==="string"&&Number.isFinite(e.x)&&Number.isFinite(e.y)&&Number.isFinite(e.hp)&&Number.isFinite(e.hpMax)):null;
    if(restoredEnemies)this.enemies=restoredEnemies.map(e=>({...e,alive:e.alive!==false,attackTimer:Math.max(0,Number(e.attackTimer)||0),phase:Number(e.phase)||0}));
    else this.spawnInitial();
    this.drops=Array.isArray(saved?.drops)?saved.drops.filter(d=>d&&Number.isFinite(d.x)&&Number.isFinite(d.y)&&typeof d.type==="string"):[];
    this.updateRegion();this.hp=clamp(this.hp,1,this.maxHp);
  }
  get klass(){return CLASSES[this.classId]} get maxHp(){return this.klass.maxHp+(this.level-1)*12+this.stat("health")} get attack(){return this.klass.attack+(this.level-1)*2+this.stat("attack")} get defense(){return this.klass.defense} get power(){return Math.round(this.level*12+this.attack*4+this.maxHp*.35+this.stat("defense")*8)}
  stat(key){return Object.values(this.equipment).reduce((n,item)=>n+(item?.[key]||0),0)}
  spawnInitial(){for(const point of SPAWN_POINTS){const type=ENEMIES.find(enemy=>enemy.id===point.enemy);if(type)this.enemies.push(this.makeEnemy(type,point.x,point.y,point.id,point.region));}}
  makeEnemy(type,x,y,spawnId=null,regionId=null){return {...type,x,y,homeX:x,homeY:y,spawnId,regionId:regionId||REGIONS.find(r=>y>=r.minY&&y<r.maxY)?.id||"village",hp:type.hp,hpMax:type.hp,attackTimer:rand(0,10)/10,phase:Math.random()*6,alive:true,respawnTimer:0}}
  update(dt,input){
    this.clock+=dt;this.autosaveTimer+=dt;if(this.autosaveTimer>=8){this.autosaveTimer=0;writeSave(this)}this.player.attackTimer=Math.max(0,this.player.attackTimer-dt);this.player.skillTimer=Math.max(0,this.player.skillTimer-dt);this.player.flash=Math.max(0,this.player.flash-dt);
    const d=input.getDirection();if(Math.hypot(d.x,d.y)>.08){this.player.x=clamp(this.player.x+d.x*220*dt,38,862);this.player.y=clamp(this.player.y+d.y*220*dt,70,1480);this.target=null}
    this.updateRegion();
    for(const e of this.enemies){
      if(!e.alive){
        if(e.respawnTimer>0){
          e.respawnTimer=Math.max(0,e.respawnTimer-dt);
          if(e.respawnTimer===0){
            e.alive=true;e.hp=e.hpMax;e.x=e.homeX??e.x;e.y=e.homeY??e.y;e.attackTimer=.6;e.phase=Math.random()*6;
          }
        }
        continue;
      }
      e.phase+=dt;
      const dist=this.distance(this.player,e);
      if(this.player.y<390){e.attackTimer=Math.max(0,e.attackTimer-dt);continue}
      if(dist<290&&dist>37){
        e.x+=(this.player.x-e.x)/dist*e.speed*dt;
        e.y+=(this.player.y-e.y)/dist*e.speed*dt;
      }else if(dist>360){
        const homeDist=Math.hypot((e.homeX??e.x)-e.x,(e.homeY??e.y)-e.y);
        if(homeDist>3){
          e.x+=((e.homeX??e.x)-e.x)/homeDist*e.speed*1.25*dt;
          e.y+=((e.homeY??e.y)-e.y)/homeDist*e.speed*1.25*dt;
        }
      }
      if(dist<43&&e.attackTimer<=0){this.takeDamage(e.attack);e.attackTimer=e.boss?1.45:1.25}else e.attackTimer-=dt;
    }
    if(this.auto){if(!this.target||!this.target.alive)this.target=this.nearest(this.klass.range+180);if(this.target){const dist=this.distance(this.player,this.target);if(dist>this.klass.range){const dx=(this.target.x-this.player.x)/dist,dy=(this.target.y-this.player.y)/dist;this.player.x+=dx*150*dt;this.player.y+=dy*150*dt}else this.basicAttack()}}
    this.drops=this.drops.filter(drop=>{if(this.distance(this.player,drop)<42){if(drop.type==="gold")this.gold+=drop.amount;else if(drop.type==="exp")this.gainExp(drop.amount);else this.inventory.push(drop.item);this.toast(drop.label);return false}return true});
    this.effects=this.effects.filter(f=>{f.life-=dt;return f.life>0});this.damageTexts=this.damageTexts.filter(t=>{t.life-=dt;t.y-=24*dt;return t.life>0});
    if(this.noticeTime>0)this.noticeTime-=dt;
  }
  distance(a,b){return Math.hypot(a.x-b.x,a.y-b.y)}
  nearest(range=400){let best=null,dist=range;for(const e of this.enemies){if(!e.alive)continue;const d=this.distance(this.player,e);if(d<dist){best=e;dist=d}}return best}
  basicAttack(){if(this.player.attackTimer>0)return;let target=this.target?.alive?this.target:this.nearest(this.klass.range);if(!target)return;const dist=this.distance(this.player,target);if(dist>this.klass.range)return;this.target=target;const damage=Math.round(this.attack*(Math.random()<.12?1.8:1));target.hp-=damage;this.player.attackTimer=.72;this.effects.push({x:target.x,y:target.y,life:.25,max:.25,type:"hit"});this.damageTexts.push({x:target.x,y:target.y-35,text:String(damage),life:.8});if(target.hp<=0)this.defeat(target)}
  manualAttack(){const target=this.nearest(this.klass.range+20);if(target){this.target=target;this.basicAttack()}else this.toast("附近没有可攻击的目标")}
  castSkill(){if(this.player.skillTimer>0){this.toast("技能冷却中");return}const c=this.klass;this.player.skillTimer=c.skillCooldown;this.effects.push({x:this.player.x,y:this.player.y,life:.55,max:.55,type:"skill"});if(this.classId==="taoist"){const healed=Math.min(this.maxHp-this.hp,Math.round(this.maxHp*.28));this.hp+=healed;this.toast("灵符治疗 +" + healed);return}
    const targets=this.enemies.filter(e=>e.alive&&this.distance(this.player,e)<(this.classId==="warrior"?145:260));if(!targets.length){this.toast("技能已释放");return}for(const e of targets){const dmg=Math.round(this.attack*c.skillPower*(1+this.skillLevel*.12));e.hp-=dmg;this.damageTexts.push({x:e.x,y:e.y-35,text:String(dmg),life:.9});if(e.hp<=0)this.defeat(e)}this.toast(c.skill+" 命中 "+targets.length+" 个目标")}
  takeDamage(amount){const real=Math.max(1,Math.round(amount*this.defense)-this.stat("defense"));this.hp-=real;this.player.flash=.2;this.damageTexts.push({x:this.player.x,y:this.player.y-48,text:"-"+real,life:.7});if(this.hp<=0){this.hp=1;this.player.x=450;this.player.y=330;this.auto=false;this.toast("你已返回新手村，生命恢复");this.hp=this.maxHp}}
  defeat(e){if(!e.alive)return;e.alive=false;e.respawnTimer=e.boss?90:e.elite?42:24;this.kills++;if(this.questAccepted&&!this.questClaimed&&e.id==="forest_beast")this.questKills++;this.gainExp(e.xp);const gold=rand(...e.gold);this.drops.push({x:e.x+15,y:e.y,type:"gold",amount:gold,label:"金币 +"+gold});if(Math.random()<.35||e.elite)this.drops.push({x:e.x-12,y:e.y+8,type:"gear",item:GEAR[rand(0,GEAR.length-1)],label:"发现装备"});if(e.boss){this.drops.push({x:e.x,y:e.y,type:"gear",item:GEAR[3],label:"获得传说装备"});this.toast("腐化古树被击败！")}else this.toast(e.elite?"精英怪已击败":"怪物已击败");this.target=null;this.onChange()}
  gainExp(amount){this.exp+=amount;while(this.exp>=this.level*100){this.exp-=this.level*100;this.level++;this.skillPoints++;this.hp=this.maxHp;this.toast("等级提升！当前等级 "+this.level+" · 获得技能点") }}
  switchClass(nextId){if(!CLASSES[nextId]||nextId===this.classId)return false;const ratio=this.hp/this.maxHp;this.classId=nextId;this.hp=Math.max(1,Math.round(this.maxHp*ratio));this.toast("已切换职业："+this.klass.name);return true}
  upgradeSkill(){if(this.skillPoints<=0||this.skillLevel>=5)return false;this.skillPoints--;this.skillLevel++;this.toast("技能提升至 "+this.skillLevel+" 级");return true}
  usePotion(){if(this.potions<=0){this.toast("药水不足");return}if(this.hp>=this.maxHp){this.toast("生命值已满");return}this.potions--;const heal=Math.round(this.maxHp*.45);this.hp=Math.min(this.maxHp,this.hp+heal);this.toast("恢复生命 +"+heal)}
  toggleAuto(){this.auto=!this.auto;this.toast(this.auto?"自动战斗已开启":"自动战斗已关闭")}
  updateRegion(){const r=REGIONS.find(x=>this.player.y>=x.minY&&this.player.y<x.maxY)||REGIONS[0];if(r.id!==this.region){this.region=r.id;this.toast("进入 "+r.name);if(r.id==="altar"&&!this.enemies.some(e=>e.boss)){this.enemies.push(this.makeEnemy(ENEMIES[3],450,1330,"altar_boss","altar"))}}}
  acceptQuest(){this.questAccepted=true;this.questKills=0;this.toast("已接取：击败 3 名森林劫掠者")}
  claimQuest(){if(this.questKills<3||this.questClaimed){this.toast("任务条件尚未满足");return}this.questClaimed=true;this.gainExp(80);this.inventory.push({id:"quest_badge",name:"巡林者徽记",slot:"armor",quality:"优秀",health:20,attack:0,defense:1});this.toast("任务完成：获得 80 经验与徽记")}
  toast(message){this.notice=message;this.noticeTime=2.1}
  save(){const ok=writeSave(this);this.toast(ok?"本地存档成功":"存档失败，请检查浏览器空间")}
  snapshot(){return {level:this.level,exp:this.exp,gold:this.gold,potions:this.potions,hp:this.hp,maxHp:this.maxHp,attack:this.attack,power:this.power,classId:this.classId,klass:this.klass,region:this.region,kills:this.kills,questKills:this.questKills,skillPoints:this.skillPoints,questAccepted:this.questAccepted,questClaimed:this.questClaimed,inventory:this.inventory,equipment:this.equipment,skillLevel:this.skillLevel,auto:this.auto,target:this.target}}
}
