const KEY="hero-world-html5-save-v1";
const SAVE_VERSION=3;

export function loadSave(){
  try{
    const raw=localStorage.getItem(KEY);
    if(!raw)return null;
    const data=JSON.parse(raw);
    if(!data||typeof data!=="object")return null;
    if(data.version===1||data.version===2)return {...data,version:SAVE_VERSION};
    return data.version===SAVE_VERSION?data:null;
  }catch(error){
    console.warn("Save data could not be read",error);
    return null;
  }
}

export function writeSave(state){
  const payload={
    version:SAVE_VERSION,
    level:state.level,exp:state.exp,gold:state.gold,potions:state.potions,hp:state.hp,classId:state.classId,
    x:state.player.x,y:state.player.y,kills:state.kills,questKills:state.questKills,skillPoints:state.skillPoints,
    questAccepted:state.questAccepted,questClaimed:state.questClaimed,inventory:state.inventory,equipment:state.equipment,
    skillLevel:state.skillLevel,region:state.region,
    enemies:state.enemies.map(enemy=>({...enemy})),
    drops:state.drops.map(drop=>({...drop,item:drop.item?{...drop.item}:undefined}))
  };
  try{
    localStorage.setItem(KEY,JSON.stringify(payload));
    return true;
  }catch(error){
    console.warn("Save failed",error);
    return false;
  }
}
