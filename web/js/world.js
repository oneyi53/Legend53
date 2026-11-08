// Shared deterministic world layout for rendering and movement collision.
export const TREE_PLACEMENTS = Array.from({length:38},(_,i)=>({
  x:(i*173+71)%870,
  y:410+(i*239)%1050,
  scale:0.72+(i%4)*0.13
}));

// Collision uses the visible trunk footprint, not the full canopy.
export function isBlockedByTree(x,y,playerRadius=12){
  return TREE_PLACEMENTS.some(tree=>{
    const dx=x-tree.x;
    const dy=y-(tree.y+3);
    const radius=11*tree.scale+playerRadius;
    return dx*dx+dy*dy<radius*radius;
  });
}
