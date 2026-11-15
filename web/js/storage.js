const KEY="hero-world-html5-save-v1";
const SAVE_VERSION=5;

export function loadSave(){
  try{
    const raw=localStorage.getItem(KEY);
    if(!raw)return null;
    const data=JSON.parse(raw);
    if(!data||typeof data!=="object")return null;
    if(data.version===1||data.version===2||data.version===3||data.version===4)return {...data,version:SAVE_VERSION};
    return data.version===SAVE_VERSION?data:null;
  }catch(error){
    console.warn("Save data could not be read",error);
    return null;
  }
}

export function writeSave(state){
  const payload={
    version:SAVE_VERSION,
    name:state.name,mp:state.mp,dead:!!state.dead,
    level:state.level,exp:state.exp,gold:state.gold,potions:state.potions,hp:state.hp,classId:state.classId,
    x:state.player.x,y:state.player.y,kills:state.kills,questKills:state.questKills,skillPoints:state.skillPoints,
    questAccepted:state.questAccepted,questClaimed:state.questClaimed,deepwoodQuestAccepted:state.deepwoodQuestAccepted,deepwoodQuestClaimed:state.deepwoodQuestClaimed,deepwoodEntered:state.deepwoodEntered,deepwoodEliteKills:state.deepwoodEliteKills,questMaterials:state.questMaterials,inventory:state.inventory,equipment:state.equipment,
    skillLevel:state.skillLevel,gearSequence:state.gearSequence,region:state.region,
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

// Start a fresh single-slot save (used when creating a new character).
// The old single save slot is overwritten; this is the documented single-save rule.
export function resetSave(classId, name){
  const payload={version:SAVE_VERSION,name:name||"无名旅者",mp:null,dead:false,
    level:1,exp:0,gold:100,potions:3,hp:null,classId:classId||"warrior",
    x:450,y:330,kills:0,questKills:0,skillPoints:0,
    questAccepted:false,questClaimed:false,deepwoodQuestAccepted:false,deepwoodQuestClaimed:false,
    deepwoodEntered:false,deepwoodEliteKills:0,questMaterials:0,inventory:[],equipment:{},
    skillLevel:1,gearSequence:0,region:"village",enemies:[],drops:[]};
  try{localStorage.setItem(KEY,JSON.stringify(payload));return true;}
  catch(error){console.warn("Save reset failed",error);return false;}
}
