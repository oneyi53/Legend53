export const CLASSES = {
  warrior:{name:"战士",maxHp:135,attack:18,defense:.72,range:72,skill:"旋风斩",skillPower:2.2,skillCooldown:7,art:"warrior.svg"},
  mage:{name:"法师",maxHp:88,attack:15,defense:1.12,range:205,skill:"烈焰火球",skillPower:2.8,skillCooldown:8,art:"mage.svg"},
  taoist:{name:"道士",maxHp:108,attack:16,defense:.9,range:150,skill:"灵符治疗",skillPower:1.8,skillCooldown:9,art:"taoist.svg"}
};
export const REGIONS=[
  {id:"village",name:"守林新手村",level:1,minY:0,maxY:390,tint:"#526b4c"},
  {id:"entrance",name:"林间入口",level:1,minY:390,maxY:560,tint:"#3d5b43"},
  {id:"deepwood",name:"幽暗密林",level:3,minY:560,maxY:850,tint:"#304c3c"},
  {id:"ruins",name:"古代遗迹",level:5,minY:850,maxY:1160,tint:"#5a5543"},
  {id:"altar",name:"遗忘祭坛",level:8,minY:1160,maxY:1550,tint:"#57433b"}
];
export const ENEMIES=[
  {id:"forest_beast",name:"森林劫掠者",hp:54,attack:7,defense:1,speed:48,xp:22,gold:[5,12],color:"#9a6543"},
  {id:"thorn_wolf",name:"荆棘野狼",hp:68,attack:9,defense:2,speed:64,xp:28,gold:[8,16],color:"#77836b"},
  {id:"ruin_guard",name:"遗迹守卫",hp:150,attack:15,defense:5,speed:34,xp:65,gold:[18,30],color:"#89908a",elite:true},
  {id:"ancient_tree",name:"腐化古树",hp:1200,attack:24,defense:10,speed:22,xp:500,gold:[120,180],boss:true,color:"#876047"}
];
export const GEAR=[
  {id:"wood_blade",name:"林木短剑",slot:"weapon",quality:"普通",attack:4,health:0,defense:0},
  {id:"hunter_coat",name:"巡林者皮甲",slot:"armor",quality:"优秀",attack:0,health:28,defense:2},
  {id:"ruin_ring",name:"遗迹守护戒",slot:"ring",quality:"稀有",attack:3,health:12,defense:2},
  {id:"ancient_relic",name:"古树核心坠饰",slot:"necklace",quality:"传说",attack:10,health:45,defense:4}
];
export const SLOT_NAMES={weapon:"武器",helmet:"头盔",necklace:"项链",bracelet:"手镯",ring:"戒指",armor:"护甲",belt:"腰带",boots:"鞋子"};
