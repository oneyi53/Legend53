const KEY="hero-world-html5-save-v1";
export function loadSave(){
  try{const raw=localStorage.getItem(KEY);if(!raw)return null;const data=JSON.parse(raw);return data&&data.version===1?data:null}
  catch(error){console.warn("Save data could not be read",error);return null}
}
export function writeSave(state){
  const payload={version:1,level:state.level,exp:state.exp,gold:state.gold,potions:state.potions,hp:state.hp,classId:state.classId,
    x:state.player.x,y:state.player.y,kills:state.kills,questKills:state.questKills,skillPoints:state.skillPoints,questAccepted:state.questAccepted,questClaimed:state.questClaimed,
    inventory:state.inventory,equipment:state.equipment,skillLevel:state.skillLevel,region:state.region};
  try{localStorage.setItem(KEY,JSON.stringify(payload));return true}catch(error){console.warn("Save failed",error);return false}
}
