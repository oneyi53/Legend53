export class InputController{
  constructor(canvas,game){this.canvas=canvas;this.game=game;this.pointer=null;this.origin={x:0,y:0};this.vector={x:0,y:0};this.keys=new Set();
    canvas.addEventListener("pointerdown",e=>this.down(e));window.addEventListener("pointermove",e=>this.move(e));window.addEventListener("pointerup",e=>this.up(e));window.addEventListener("pointercancel",e=>this.up(e));
    window.addEventListener("keydown",e=>{if(e.target&&/INPUT|TEXTAREA/.test(e.target.tagName))return;if(["w","a","s","d","ArrowUp","ArrowDown","ArrowLeft","ArrowRight"].includes(e.key)){this.keys.add(e.key);e.preventDefault()}});
    window.addEventListener("keyup",e=>this.keys.delete(e.key));window.addEventListener("blur",()=>{this.pointer=null;this.vector={x:0,y:0};this.keys.clear()});
  }
  down(e){if(e.target!==this.canvas||this.pointer!==null)return;this.pointer=e.pointerId;const r=this.canvas.getBoundingClientRect();const scale=Math.min(r.width/720,r.height/1280),ox=(r.width-720*scale)/2,oy=(r.height-1280*scale)/2;this.origin={x:(e.clientX-r.left-ox)/scale,y:(e.clientY-r.top-oy)/scale};this.vector={x:0,y:0};this.canvas.setPointerCapture?.(e.pointerId)}
  move(e){if(e.pointerId!==this.pointer)return;const r=this.canvas.getBoundingClientRect(),fit=Math.min(r.width/720,r.height/1280),ox=(r.width-720*fit)/2,oy=(r.height-1280*fit)/2,px=(e.clientX-r.left-ox)/fit,py=(e.clientY-r.top-oy)/fit,dx=px-this.origin.x,dy=py-this.origin.y,len=Math.hypot(dx,dy)||1,scale=Math.min(1,len/54);this.vector={x:dx/len*scale,y:dy/len*scale}}
  up(e){if(e.pointerId!==this.pointer)return;this.pointer=null;this.vector={x:0,y:0}}
  getDirection(){let x=this.vector.x,y=this.vector.y;if(this.keys.has("a")||this.keys.has("ArrowLeft"))x-=1;if(this.keys.has("d")||this.keys.has("ArrowRight"))x+=1;if(this.keys.has("w")||this.keys.has("ArrowUp"))y-=1;if(this.keys.has("s")||this.keys.has("ArrowDown"))y+=1;const len=Math.hypot(x,y);return len>1?{x:x/len,y:y/len}:{x,y}}
  draw(ctx){if(this.pointer===null)return;ctx.save();ctx.globalAlpha=.72;ctx.strokeStyle="#e6d5aa";ctx.lineWidth=2;ctx.fillStyle="#182820aa";ctx.beginPath();ctx.arc(this.origin.x,this.origin.y,55,0,Math.PI*2);ctx.fill();ctx.stroke();ctx.beginPath();ctx.arc(this.origin.x+this.vector.x*35,this.origin.y+this.vector.y*35,23,0,Math.PI*2);ctx.fillStyle="#d4d9bd";ctx.fill();ctx.stroke();ctx.restore()}
}
