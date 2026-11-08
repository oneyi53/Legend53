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


// A* pathfinding on a 32px grid. Diagonal moves cannot cut through tree corners.
export function findPath(startX,startY,goalX,goalY,entityRadius=12){
  const minX=38,minY=70,step=32,cols=26,rows=45;
  const toCell=(x,y)=>({c:Math.max(0,Math.min(cols-1,Math.round((x-minX)/step))),r:Math.max(0,Math.min(rows-1,Math.round((y-minY)/step)))});
  const point=(c,r)=>({x:minX+c*step,y:minY+r*step});
  const key=(c,r)=>r*cols+c;
  const start=toCell(startX,startY),rawGoal=toCell(goalX,goalY);
  const blocked=(c,r)=>{const p=point(c,r);return isBlockedByTree(p.x,p.y,entityRadius)};
  const nearestOpen=(cell)=>{
    if(!blocked(cell.c,cell.r))return cell;
    for(let radius=1;radius<=4;radius++){
      for(let r=Math.max(0,cell.r-radius);r<=Math.min(rows-1,cell.r+radius);r++){
        for(let c=Math.max(0,cell.c-radius);c<=Math.min(cols-1,cell.c+radius);c++){
          if(Math.max(Math.abs(c-cell.c),Math.abs(r-cell.r))===radius&&!blocked(c,r))return {c,r};
        }
      }
    }
    return null;
  };
  const safeStart=nearestOpen(start),goal=nearestOpen(rawGoal);
  if(!safeStart||!goal)return null;
  const startKey=key(safeStart.c,safeStart.r),goalKey=key(goal.c,goal.r);
  if(startKey===goalKey)return [];
  const open=[{c:safeStart.c,r:safeStart.r,g:0,f:Math.hypot(goal.c-safeStart.c,goal.r-safeStart.r)}];
  const cameFrom=new Map(),cost=new Map([[startKey,0]]),closed=new Set();
  const dirs=[[-1,0,1],[1,0,1],[0,-1,1],[0,1,1],[-1,-1,Math.SQRT2],[1,-1,Math.SQRT2],[-1,1,Math.SQRT2],[1,1,Math.SQRT2]];
  let found=false,visited=0;
  while(open.length&&visited++<1800){
    let best=0;for(let i=1;i<open.length;i++)if(open[i].f<open[best].f)best=i;
    const current=open.splice(best,1)[0],currentKey=key(current.c,current.r);
    if(closed.has(currentKey)||current.g!==cost.get(currentKey))continue;
    if(currentKey===goalKey){found=true;break}
    closed.add(currentKey);
    for(const [dc,dr,weight] of dirs){
      const c=current.c+dc,r=current.r+dr;
      if(c<0||c>=cols||r<0||r>=rows||blocked(c,r))continue;
      if(dc&&dr&&(blocked(current.c+dc,current.r)||blocked(current.c,current.r+dr)))continue;
      const nextKey=key(c,r),nextCost=current.g+weight;
      if(closed.has(nextKey)||nextCost>=(cost.get(nextKey)??Infinity))continue;
      cost.set(nextKey,nextCost);cameFrom.set(nextKey,currentKey);
      open.push({c,r,g:nextCost,f:nextCost+Math.hypot(goal.c-c,goal.r-r)});
    }
  }
  if(!found)return null;
  const path=[];let cursor=goalKey;
  while(cursor!==startKey){
    const c=cursor%cols,r=Math.floor(cursor/cols);path.push(point(c,r));
    cursor=cameFrom.get(cursor);if(cursor===undefined)return null;
  }
  path.reverse();
  return path;
}
