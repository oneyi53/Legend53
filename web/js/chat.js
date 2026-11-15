// Local-only chat. There is no server and no other player: messages are kept
// on this device, channel prefixes follow the report (§1.4, [确认] commands).
//   !...  world (Lv.8+; below that the message is refused, per the report)
//   !!... party   !~... guild   /name text  whisper   anything else  nearby
export const CHANNELS = [
  { id: "all", label: "综合" },
  { id: "nearby", label: "附近" },
  { id: "world", label: "世界" },
  { id: "party", label: "组队" },
  { id: "guild", label: "行会" },
  { id: "system", label: "系统" },
];

export class ChatLog {
  constructor(logEl) {
    this.logEl = logEl;
    this.channel = "all";
    this.messages = { all: [], nearby: [], world: [], party: [], guild: [], system: [] };
    this.system("欢迎来到玛法大陆（单机版）。聊天仅保存在本机。");
  }
  add(channel, text, cls = "") {
    const list = this.messages[channel] || this.messages.all;
    list.push({ text, cls });
    if (list.length > 50) list.shift();
    if (channel !== "all") this.messages.all.push({ text: `[${this.label(channel)}] ${text}`, cls });
    if (this.messages.all.length > 50) this.messages.all.shift();
    this.render();
  }
  label(channel) {
    return (CHANNELS.find((c) => c.id === channel) || {}).label || channel;
  }
  system(text) {
    this.add("system", text, "chat-system");
  }
  // Returns false when the message is refused (caller shows the reason).
  send(text, level, playerName) {
    const raw = (text || "").trim();
    if (!raw) return true;
    if (raw.startsWith("!!")) {
      this.add("party", `${playerName}：${raw.slice(2).trim()}`);
      return true;
    }
    if (raw.startsWith("!~")) {
      this.add("guild", `${playerName}：${raw.slice(2).trim()}`);
      return true;
    }
    if (raw.startsWith("!")) {
      if (level < 8) {
        this.system("需要达到 8 级才能全服喊话。");
        return false;
      }
      this.add("world", `${playerName}：${raw.slice(1).trim()}`);
      return true;
    }
    const whisper = raw.match(/^\/(\S+)\s+(.+)$/);
    if (whisper) {
      this.add("system", `你对 ${whisper[1]} 说：${whisper[2]}（单机版无其他玩家，仅作记录）`, "chat-system");
      return true;
    }
    this.add("nearby", `${playerName}：${raw}`);
    return true;
  }
  setChannel(channel) {
    if (this.messages[channel]) {
      this.channel = channel;
      this.render();
    }
  }
  render() {
    if (!this.logEl) return;
    const list = this.messages[this.channel] || [];
    this.logEl.innerHTML = list
      .map((m) => `<div class="chat-line ${m.cls || ""}">${escapeHtml(m.text)}</div>`)
      .join("") || '<div class="chat-line chat-empty">暂无消息</div>';
    this.logEl.scrollTop = this.logEl.scrollHeight;
  }
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}
