import { Game } from "./game.js";
import { InputController } from "./input.js";
import { Renderer } from "./renderer.js";
import { CLASSES, SLOT_NAMES, SHOP_ITEMS, DEEPWOOD_QUEST, REGIONS, NPCS } from "./data.js";
import { resetSave, loadSave } from "./storage.js";
import { ChatLog, CHANNELS } from "./chat.js";
import { listProfiles, getActiveProfile, getRememberedAccount, rememberAccount, createProfile, setActiveProfile, deleteActiveProfile, randomName } from "./profiles.js";

const $ = (id) => document.getElementById(id);
// 背包格数占位：8×5=40，待原版截图核对后改这两个常量（report §4.2 [待核]）。
const BAG_COLS = 8, BAG_ROWS = 5;
const CLASS_ORDER = ["warrior", "mage", "taoist"];
const CLASS_DESC = { warrior: "近战物理 · 高血高防", mage: "远程法术 · 魔法强大但体魄弱", taoist: "治疗施毒 · 可召唤助战" };
const ATTACK_MODES = ["和平", "全体", "行会", "组队", "善恶"]; // 仅显示：单机无 PK 对象

// ---------------- 流程屏 ----------------
const screens = ["screen-login", "screen-server", "screen-select", "screen-create"];
function showScreen(id) {
  for (const s of screens) $(s).classList.add("hidden");
  $("game-shell").classList.add("hidden");
  if (id) $(id).classList.remove("hidden");
}
$("login-account").value = getRememberedAccount();
$("login-button").addEventListener("click", () => {
  const account = $("login-account").value.trim();
  if (!account) {
    $("login-error").textContent = "请输入账号";
    $("login-error").classList.remove("hidden");
    return;
  }
  $("login-error").classList.add("hidden");
  if ($("login-remember").checked) rememberAccount(account);
  showScreen("screen-server");
});
$("server-back").addEventListener("click", () => showScreen("screen-login"));
$("server-enter").addEventListener("click", () => { renderSelect(); showScreen("screen-select"); });
document.querySelectorAll(".server-row").forEach((b) => b.addEventListener("click", () => {
  document.querySelectorAll(".server-row").forEach((x) => x.classList.remove("selected"));
  b.classList.add("selected");
}));

function renderSelect() {
  const profile = getActiveProfile();
  const save = loadSave();
  const shownClass = (save?.classId && CLASSES[save.classId]) ? save.classId : profile?.classId;
  $("char-list").innerHTML = profile
    ? `<button class="char-card selected" data-char="${profile.id}">
         <img src="./assets/characters/${CLASSES[shownClass].art}" alt="${CLASSES[shownClass].name}">
         <span><b>${escapeHtml(profile.name)}</b><small>Lv.${save?.level || 1} ${CLASSES[shownClass].name} · ${profile.gender}</small></span>
       </button>`
    : `<div class="char-card empty">空角色位</div>`;
  $("char-enter").textContent = profile ? "进入游戏" : "创建角色";
  $("char-delete").style.visibility = profile ? "visible" : "hidden";
}
$("char-enter").addEventListener("click", () => {
  const profile = getActiveProfile();
  if (profile) enterGame(profile);
  else showScreen("screen-create");
});
$("char-create").addEventListener("click", () => showScreen("screen-create"));
$("char-delete").addEventListener("click", (e) => {
  if (!getActiveProfile()) return;
  if (!e.currentTarget.dataset.armed) {
    e.currentTarget.dataset.armed = "1";
    e.currentTarget.textContent = "再点一次确认删除";
    return;
  }
  deleteActiveProfile();
  resetSave("warrior", "无名旅者");
  renderSelect();
});
$("select-back").addEventListener("click", () => showScreen("screen-server"));

// ---------------- 建角 ----------------
let createClassIdx = 0, createGender = "男";
function renderCreate() {
  const id = CLASS_ORDER[createClassIdx], c = CLASSES[id];
  $("create-art").src = "./assets/characters/" + c.art;
  $("create-class-name").textContent = c.name;
  $("create-class-desc").textContent = CLASS_DESC[id];
  $("create-gender-m").classList.toggle("selected", createGender === "男");
  $("create-gender-f").classList.toggle("selected", createGender === "女");
}
$("create-prev").addEventListener("click", () => { createClassIdx = (createClassIdx + CLASS_ORDER.length - 1) % CLASS_ORDER.length; renderCreate(); });
$("create-next").addEventListener("click", () => { createClassIdx = (createClassIdx + 1) % CLASS_ORDER.length; renderCreate(); });
$("create-gender-m").addEventListener("click", () => { createGender = "男"; renderCreate(); });
$("create-gender-f").addEventListener("click", () => { createGender = "女"; renderCreate(); });
$("create-dice").addEventListener("click", () => { $("create-name").value = randomName(); });
$("create-back").addEventListener("click", () => { renderSelect(); showScreen("screen-select"); });
$("create-confirm").addEventListener("click", () => {
  const name = $("create-name").value.trim() || randomName();
  if (listProfiles().length > 0 && !window.confirm("创建新角色会覆盖当前单机存档，确定吗？")) return;
  const profile = createProfile({ name, classId: CLASS_ORDER[createClassIdx], gender: createGender });
  resetSave(profile.classId, profile.name);
  enterGame(profile);
});
renderCreate();

// ---------------- 进入游戏 ----------------
let booted = false;
function enterGame(profile) {
  setActiveProfile(profile.id);
  for (const s of screens) $(s).classList.add("hidden");
  $("game-shell").classList.remove("hidden");
  if (!booted) {
    booted = true;
    bootGame(profile);
  }
}

function escapeHtml(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// ---------------- 游戏启动与 HUD ----------------
function bootGame(profile) {
  const canvas = $("game-canvas");
  const game = new Game();
  const input = new InputController(canvas, game);
  const renderer = new Renderer(canvas, game, input);
  const chat = new ChatLog($("chat-log"));
  let last = performance.now();
  let lastNotice = "", lastArt = "", modeIdx = 0, selectedBag = -1;

  // 聊天频道签
  $("chat-tabs").innerHTML = CHANNELS.map((c) => `<button data-channel="${c.id}" class="${c.id === "all" ? "active" : ""}">${c.label}</button>`).join("");
  $("chat-tabs").querySelectorAll("[data-channel]").forEach((b) => b.addEventListener("click", () => {
    $("chat-tabs").querySelectorAll("[data-channel]").forEach((x) => x.classList.remove("active"));
    b.classList.add("active");
    chat.setChannel(b.dataset.channel);
  }));
  const sendChat = () => {
    const value = $("chat-input").value;
    if (chat.send(value, game.level, game.name)) $("chat-input").value = "";
  };
  $("chat-send").addEventListener("click", sendChat);
  $("chat-expand").addEventListener("click", () => {
    $("chat-box").classList.toggle("expanded");
    const expanded = $("chat-box").classList.contains("expanded");
    $("chat-expand").textContent = expanded ? "▼" : "▲";
    // 展开的聊天会盖住交谈钮所在位置，显隐由 updateHud 按 expanded 统一处理
  });

  // F1–F8 快捷栏：F1 为职业技能，其余为空槽（本版每职业 1 个招牌技能）
  $("skill-slots").innerHTML = Array.from({ length: 8 }, (_, i) => {
    const key = "F" + (i + 1);
    return `<button class="skill-slot${i === 0 ? " bound" : " empty"}" data-slot="${key}" title="${key}${i === 0 ? " · " + game.klass.skill : " · 空"}">
      <span class="slot-key">${key}</span><span class="slot-icon">${i === 0 ? "✦" : ""}</span><em class="slot-cd"></em></button>`;
  }).join("");
  $("skill-slots").querySelectorAll("[data-slot]").forEach((b) => b.addEventListener("click", () => {
    if (b.dataset.slot === "F1") game.castSkill();
    else game.toast(b.dataset.slot + " 快捷栏为空");
  }));

  // 小地图：按 REGIONS 色带 + 玩家白点 + NPC 黄点绘制（数据来自 data.js）
  function drawMinimap(ctx, w, h, full) {
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = "#1a140d";
    ctx.fillRect(0, 0, w, h);
    for (const r of REGIONS) {
      ctx.fillStyle = r.tint;
      ctx.fillRect(0, (r.minY / 1600) * h, w, ((r.maxY - r.minY) / 1600) * h);
    }
    ctx.strokeStyle = "#8a6d3b";
    ctx.lineWidth = full ? 2 : 1;
    ctx.strokeRect(1, 1, w - 2, h - 2);
    for (const npc of NPCS) {
      ctx.fillStyle = "#ffd75e";
      ctx.beginPath();
      ctx.arc((npc.x / 900) * w, (npc.y / 1600) * h, full ? 5 : 2, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.fillStyle = "#fff";
    ctx.beginPath();
    ctx.arc((game.player.x / 900) * w, (game.player.y / 1600) * h, full ? 6 : 3, 0, Math.PI * 2);
    ctx.fill();
    if (full) {
      ctx.fillStyle = "#fff";
      ctx.font = "12px sans-serif";
      ctx.textAlign = "left";
      for (const r of REGIONS) ctx.fillText(r.name, 8, (r.minY / 1600) * h + 16);
    }
  }

  function updateHud() {
    const s = game.snapshot();
    if (lastArt !== s.klass.art) {
      lastArt = s.klass.art;
      $("avatar").src = "./assets/characters/" + s.klass.art;
    }
    $("player-name").textContent = s.name;
    $("level-label").textContent = "Lv." + s.level;
    $("class-label").textContent = s.klass.name;
    $("hp-fill").style.width = (s.hp / s.maxHp * 100) + "%";
    $("hp-value").textContent = Math.ceil(s.hp) + "/" + s.maxHp;
    $("mp-fill").style.width = (s.mp / s.maxMp * 100) + "%";
    $("mp-value").textContent = Math.ceil(s.mp) + "/" + s.maxMp;
    $("hp-orb-value").textContent = Math.ceil(s.hp);
    $("mp-orb-value").textContent = Math.ceil(s.mp);
    const region = REGIONS.find((r) => r.id === s.region) || REGIONS[0];
    $("region-label").textContent = region.name;
    $("coords-label").textContent = Math.round(game.player.x) + "," + Math.round(game.player.y);
    $("zone-level").textContent = "推荐 Lv." + region.level;
    $("exp-fill").style.width = (s.exp / (s.level * 100) * 100) + "%";
    $("exp-value").textContent = s.exp + "/" + (s.level * 100);
    $("potion-count").textContent = s.potions;
    $("skill-name").textContent = s.klass.skill;
    $("skill-button").classList.toggle("cooling", game.player.skillTimer > 0);
    $("skill-cooldown").textContent = game.player.skillTimer > 0 ? Math.ceil(game.player.skillTimer) : "";
    $("auto-button").classList.toggle("active", s.auto);
    const f1 = $("skill-slots").querySelector('[data-slot="F1"]');
    if (f1) {
      f1.classList.toggle("cooling", game.player.skillTimer > 0);
      f1.querySelector(".slot-cd").textContent = game.player.skillTimer > 0 ? Math.ceil(game.player.skillTimer) : "";
    }
    $("quest-title").textContent = game.questClaimed ? "森林守护者" : "清理林间";
    $("quest-progress").textContent = game.questClaimed ? "主线已完成"
      : game.questAccepted ? Math.min(3, game.questKills) + " / 3 名森林劫掠者" : "与守林村长交谈并接取任务";
    const npc = game.nearbyNpc;
    const chatExpanded = $("chat-box").classList.contains("expanded");
    $("npc-button").classList.toggle("hidden", !npc || chatExpanded);
    if (npc) $("npc-button").textContent = npc.id === "village_smith" ? "铁匠铺" : npc.id === "village_elder" ? "村长" : "交谈";
    const target = s.target;
    $("target-banner").classList.toggle("hidden", !target?.alive);
    if (target?.alive) {
      $("target-name").textContent = target.name;
      $("target-fill").style.width = (Math.max(0, target.hp / target.hpMax) * 100) + "%";
      $("target-health").textContent = Math.max(0, Math.ceil(target.hp)) + "/" + target.hpMax;
    }
    if (game.noticeTime > 0) {
      $("toast").textContent = game.notice;
      $("toast").classList.add("show");
      if (game.notice !== lastNotice) {
        lastNotice = game.notice;
        chat.system(game.notice);
      }
    } else $("toast").classList.remove("show");
    $("game-shell").classList.toggle("dead", !!s.dead);
    $("death-overlay").classList.toggle("hidden", !s.dead);
    const mm = $("minimap");
    if (mm) drawMinimap(mm.getContext("2d"), mm.width, mm.height, false);
  }

  function loop(now) {
    const dt = Math.min(.04, (now - last) / 1000);
    last = now;
    game.update(dt, input);
    renderer.draw();
    updateHud();
    requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);
  window.addEventListener("beforeunload", () => game.save());

  // ---- 接线 ----
  $("attack-button").addEventListener("pointerdown", (e) => { e.preventDefault(); game.manualAttack(); });
  $("skill-button").addEventListener("pointerdown", (e) => { e.preventDefault(); game.castSkill(); });
  $("auto-button").addEventListener("pointerdown", (e) => { e.preventDefault(); game.toggleAuto(); });
  $("hp-orb").addEventListener("click", () => game.usePotion());
  $("potion-cell").addEventListener("click", () => game.usePotion());
  $("mp-orb").addEventListener("click", () => game.toast("魔法值 " + Math.ceil(game.mp) + "/" + game.maxMp + "，随时间恢复"));
  $("recall-cell").addEventListener("click", () => game.returnToVillage());
  $("avatar-card").addEventListener("click", () => openPanel("character"));
  $("minimap").addEventListener("click", () => openPanel("map"));
  $("settings-button").addEventListener("click", () => openPanel("settings"));
  $("quest-toggle").addEventListener("click", () => {
    $("quest-strip").classList.toggle("collapsed");
    $("quest-toggle").textContent = $("quest-strip").classList.contains("collapsed") ? "▸" : "▾";
  });
  $("npc-button").addEventListener("click", () => {
    const npc = game.nearbyNpc;
    if (!npc) { game.toast("靠近村民后再交谈"); return; }
    game.interactNpc(npc.id);
    openPanel("npc", npc.id);
  });
  $("side-bag").addEventListener("click", () => openPanel("inventory"));
  $("side-char").addEventListener("click", () => openPanel("character"));
  $("side-skills").addEventListener("click", () => openPanel("skills"));
  $("side-guild").addEventListener("click", () => openPanel("guild"));
  $("close-modal").addEventListener("click", closePanel);
  $("modal").addEventListener("click", (e) => { if (e.target === $("modal")) closePanel(); });
  $("death-revive").addEventListener("click", () => game.revive());

  // ---- 快捷键（输入框聚焦时除外）----
  window.addEventListener("keydown", (e) => {
    const typing = e.target && /INPUT|TEXTAREA/.test(e.target.tagName);
    if (typing) {
      if (e.key === "Enter" && e.target.id === "chat-input") sendChat();
      if (e.key === "Escape") e.target.blur();
      return;
    }
    if (e.key === "F1") { e.preventDefault(); game.castSkill(); }
    else if (/^F[2-8]$/.test(e.key)) { e.preventDefault(); game.toast(e.key + " 快捷栏为空"); }
    else if (e.key === "F9") { e.preventDefault(); openPanel("inventory"); }
    else if (e.key === "F10") { e.preventDefault(); openPanel("character"); }
    else if (e.key === "F11") { e.preventDefault(); openPanel("skills"); }
    else if (e.key === "m" || e.key === "M") openPanel("map");
    else if (e.key === "Escape") closePanel();
    else if ((e.ctrlKey || e.metaKey) && (e.key === "h" || e.key === "H")) {
      e.preventDefault();
      modeIdx = (modeIdx + 1) % ATTACK_MODES.length;
      $("mode-label").textContent = "模式：" + ATTACK_MODES[modeIdx];
      game.toast("攻击模式：" + ATTACK_MODES[modeIdx] + "（仅显示，单机无 PK 对象）");
    } else if (e.altKey && (e.key === "x" || e.key === "X")) {
      e.preventDefault();
      game.save();
      location.reload();
    } else if (e.altKey && (e.key === "q" || e.key === "Q")) {
      e.preventDefault();
      game.save();
      game.toast("已保存，可直接关闭页面");
    }
  });

  // ---------------- 面板 ----------------
  function closePanel() { $("modal").classList.add("hidden"); }
  function card(label, value) { return '<div class="stat-card"><b>' + label + '</b><span>' + value + '</span></div>'; }

  function openPanel(type, arg) {
    const title = { character: "角色信息", inventory: "背包", skills: "职业技能", quest: "主线任务", map: "地图", shop: "老铁匠铺", npc: "交谈", guild: "行会", settings: "设置" }[type] || "冒险";
    $("modal-title").textContent = title;
    const s = game.snapshot();
    let html = "";
    if (type === "character") {
      const slotAt = (id) => {
        const item = game.equipment[id];
        return '<div class="equip-slot"><b>' + SLOT_NAMES[id] + '</b><span>' + (item ? item.name : "空") + '</span>'
          + (item ? '<small>攻 +' + (item.attack || 0) + ' · 血 +' + (item.health || 0) + ' · 防 +' + (item.defense || 0) + '</small><button data-unequip="' + id + '">卸下</button>' : "") + '</div>';
      };
      html = '<div class="char-figure"><div class="equip-col">' + ["helmet", "necklace", "bracelet", "ring"].map(slotAt).join("") + '</div>'
        + '<div class="char-art"><img src="./assets/characters/' + s.klass.art + '" alt="' + s.klass.name + '"><b>' + s.name + '</b><small>' + s.klass.name + ' · ' + (profile.gender || "") + '</small></div>'
        + '<div class="equip-col">' + ["weapon", "armor", "belt", "boots"].map(slotAt).join("") + '</div></div>'
        + '<div class="panel-grid">' + card("等级", "Lv." + s.level) + card("战斗力", s.power) + card("攻击力", s.attack)
        + card("防御", s.defense) + card("生命值", s.hp + "/" + s.maxHp) + card("魔法值", Math.ceil(s.mp) + "/" + s.maxMp)
        + card("金币", s.gold) + card("击杀", s.kills) + '</div>'
        + '<div class="panel-actions class-choice">' + Object.entries(CLASSES).map(([id, c]) => '<button data-class="' + id + '">' + c.name + '</button>').join("") + '</div>';
    }
    if (type === "inventory") {
      const cells = Array.from({ length: BAG_COLS * BAG_ROWS }, (_, i) => {
        const item = game.inventory[i];
        return item
          ? `<button class="bag-cell filled q-${item.quality}" data-equip="${i}" title="${item.name} · 点击穿戴">${item.name.slice(0, 1)}<small>${item.quality}</small></button>`
          : `<span class="bag-cell"></span>`;
      }).join("");
      const sel = selectedBag >= 0 ? game.inventory[selectedBag] : null;
      const d = sel ? game.compareGear(sel) : null;
      const fmt = (n) => (n > 0 ? "+" : "") + n;
      html = '<div class="bag-grid" style="--bag-cols:' + BAG_COLS + '">' + cells + '</div>'
        + '<div class="bag-foot"><span>金币：' + s.gold + '</span><span>负重：' + game.inventory.length + '/' + (BAG_COLS * BAG_ROWS) + '</span>'
        + '<button id="bag-sort">整理</button></div>'
        + (sel ? '<div class="item-card"><div><b>' + sel.name + '</b><small>' + sel.quality + ' · ' + (SLOT_NAMES[sel.slot] || sel.slot)
          + ' · 攻 +' + (sel.attack || 0) + ' · 血 +' + (sel.health || 0) + ' · 防 +' + (sel.defense || 0) + '</small>'
          + '<small>对比当前：攻 ' + fmt(d.attack) + ' · 血 ' + fmt(d.health) + ' · 防 ' + fmt(d.defense) + '</small></div>'
          + '<button data-equip="' + selectedBag + '">穿戴</button></div>'
          : '<p class="empty-note">点一件物品查看属性并穿戴。格数 8×5=40 为占位，待原版截图核对。</p>');
    }
    if (type === "skills") {
      const others = Object.entries(CLASSES).filter(([id]) => id !== s.classId)
        .map(([, c]) => '<div class="skill-row locked"><span class="skill-ico">✦</span><div><b>' + c.skill + '（' + c.name + '）</b><small>未学习 · 切换职业后可用</small></div></div>').join("");
      html = '<div class="skill-row"><span class="skill-ico">✦</span><div><b>' + s.klass.skill + '</b><small>Lv.' + game.skillLevel + '/5 · 耗魔 ' + s.skillCost + ' · 技能点：' + game.skillPoints + '</small>'
        + '<div class="skill-prog"><i style="width:' + (game.skillLevel / 5 * 100) + '%"></i></div></div>'
        + '<button id="skill-upgrade">升级</button></div>' + others
        + '<p class="empty-note">单机版每职业 1 个招牌技能；完整技能表待后续版本。</p>';
    }
    if (type === "quest") {
      const nearElder = game.nearbyNpc?.id === "village_elder";
      const firstDone = game.questClaimed;
      const secondStage = game.deepwoodQuestClaimed ? "密林威胁已解除，村长已开放古代遗迹的调查线索。" : !game.deepwoodQuestAccepted ? "完成第一条主线并达到 Lv.3 后，可接取密林委托。" : !game.deepwoodEntered ? "前往幽暗密林，调查异常踪迹。" : game.deepwoodEliteKills < 1 ? "击败密林头目，取得腐化树皮。" : game.questMaterials < DEEPWOOD_QUEST.materialCount ? "精英已击败，拾取腐化树皮后返回村长。" : "目标已完成，返回村庄找村长交付。";
      const firstDialogue = game.questClaimed ? "第一份委托你完成得很好。" : !game.questAccepted ? "林间入口附近出现了森林劫掠者。请替村民清理 3 名劫掠者。" : game.questKills < 3 ? "森林劫掠者仍在骚扰村民。继续清理。" : "你已经完成委托！请把这份奖励收下。";
      const secondDialogue = game.deepwoodQuestClaimed ? "密林的威胁暂时解除，收下这份守护者装备。" : !game.deepwoodQuestAccepted ? "幽暗密林最近出现了强大的头目。达到 Lv.3 并完成前一项委托后，我会交给你新的任务。" : "密林深处的头目携带腐化树皮。先进入密林，再击败头目并带回 3 份树皮。";
      html = '<div class="npc-dialogue"><b>守林村长</b><p>' + firstDialogue + '</p></div>'
        + '<div class="quest-card"><b>主线一 · 清理林间</b><p>击败森林劫掠者：' + Math.min(3, game.questKills) + ' / 3</p><p>奖励：80 经验、60 金币、巡林者徽记</p><div class="panel-actions"><button id="quest-talk">与村长交谈</button><button id="quest-action">' + (game.questClaimed ? "已完成" : game.questAccepted ? (game.questKills >= 3 ? "交付任务" : "任务进行中") : "接取任务") + '</button></div></div>'
        + '<div class="quest-card"><b>主线二 · 幽暗密林的威胁</b><p>' + secondDialogue + '</p><p>阶段：' + secondStage + '</p><p>目标 1：进入幽暗密林 ' + (game.deepwoodEntered ? "✓" : "未完成") + '</p><p>目标 2：击败密林头目 ' + Math.min(1, game.deepwoodEliteKills) + ' / 1</p><p>目标 3：收集腐化树皮 ' + Math.min(DEEPWOOD_QUEST.materialCount, game.questMaterials) + ' / ' + DEEPWOOD_QUEST.materialCount + '</p><p>奖励：180 经验、160 金币、密林守护甲</p><div class="panel-actions"><button id="deepwood-accept" ' + (!firstDone || game.level < 3 || game.deepwoodQuestAccepted ? 'disabled' : '') + '>接取密林委托</button><button id="deepwood-claim" ' + (!game.deepwoodQuestAccepted || !game.deepwoodEntered || game.deepwoodEliteKills < 1 || game.questMaterials < DEEPWOOD_QUEST.materialCount || game.deepwoodQuestClaimed ? 'disabled' : '') + '>' + (game.deepwoodQuestClaimed ? "已完成" : "交付密林委托") + '</button></div></div>';
    }
    if (type === "map") {
      html = '<canvas id="map-canvas" width="360" height="480" class="map-canvas"></canvas>'
        + '<div class="item-list">' + REGIONS.map((region) => {
          const unlocked = s.level >= region.level;
          return '<div class="item-card"><b>' + region.name + ' · Lv.' + region.level + '</b><small>' + (unlocked ? (region.id === s.region ? "当前区域 · 已开放" : "已开放 · 可探索") : "未解锁 · 角色达到 Lv." + region.level + " 开放") + '</small></div>';
        }).join("") + '</div><p class="empty-note">白点是你，黄点是 NPC；区域怪物只在对应区域激活。</p>';
    }
    if (type === "shop") {
      html = '<div class="npc-dialogue"><b>老铁匠</b><p>冒险路上，趁手的武器和结实的护甲能救你的命。带够金币再来。</p></div><div class="item-list">'
        + SHOP_ITEMS.map((item) => '<div class="item-card"><div><b>' + item.name + '</b><small>' + item.description + ' · ' + item.price + ' 金币</small></div><button data-buy="' + item.id + '" ' + (game.gold < item.price ? 'disabled' : '') + '>购买</button></div>').join("")
        + '</div><p class="empty-note">当前金币：' + game.gold + ' · 装备购买后放入背包，药水直接增加库存。出售功能待后续版本。</p>';
    }
    if (type === "npc") {
      const npc = NPCS.find((n) => n.id === arg) || game.nearbyNpc;
      if (!npc) { html = '<p class="empty-note">附近没有村民。</p>'; }
      else if (npc.id === "village_smith") {
        html = '<div class="npc-dialogue"><b>老铁匠</b><p>冒险路上，趁手的武器和结实的护甲能救你的命。带够金币再来。</p></div>'
          + '<div class="panel-actions"><button data-goto="shop">购买物品</button><button data-close>离开</button></div>';
      } else {
        html = '<div class="npc-dialogue"><b>守林村长</b><p>年轻的冒险者，林间入口附近有森林劫掠者出没，村民需要你的帮助。</p></div>'
          + '<div class="panel-actions"><button data-goto="quest">查看任务</button><button data-close>离开</button></div>';
      }
    }
    if (type === "guild") {
      html = '<p class="empty-note">行会系统尚未在单机版开放（待后续版本）。</p>';
    }
    if (type === "settings") {
      html = '<div class="panel-actions"><button id="settings-save">保存存档</button><button id="settings-exit">保存并返回选角</button></div>'
        + '<p class="empty-note">传奇 · 离线单机版。存档保存在本机浏览器，每 8 秒自动保存一次。</p>';
    }
    $("modal-content").innerHTML = html;
    $("modal").classList.remove("hidden");
    const mc = $("map-canvas");
    if (mc) drawMinimap(mc.getContext("2d"), mc.width, mc.height, true);
    $("modal-content").querySelectorAll("[data-class]").forEach((b) => b.addEventListener("click", () => { game.switchClass(b.dataset.class); openPanel(type); }));
    $("modal-content").querySelectorAll("[data-buy]").forEach((b) => b.addEventListener("click", () => { game.buyShopItem(b.dataset.buy); openPanel(type); }));
    $("modal-content").querySelectorAll("[data-equip]").forEach((b) => b.addEventListener("click", () => {
      if (b.classList.contains("bag-cell")) { selectedBag = Number(b.dataset.equip); openPanel(type); return; }
      game.equipItem(Number(b.dataset.equip)); selectedBag = -1; openPanel(type);
    }));
    $("modal-content").querySelectorAll("[data-unequip]").forEach((b) => b.addEventListener("click", () => { game.unequipItem(b.dataset.unequip); openPanel(type); }));
    $("modal-content").querySelectorAll("[data-goto]").forEach((b) => b.addEventListener("click", () => openPanel(b.dataset.goto)));
    $("modal-content").querySelectorAll("[data-close]").forEach((b) => b.addEventListener("click", closePanel));
    $("bag-sort")?.addEventListener("click", () => {
      game.inventory.sort((a, b) => (a.slot || "").localeCompare(b.slot || "") || (b.attack + b.health + b.defense) - (a.attack + a.health + a.defense));
      selectedBag = -1;
      openPanel(type);
    });
    $("skill-upgrade")?.addEventListener("click", () => { if (game.upgradeSkill()) openPanel(type); else game.toast("技能点不足或技能已满级"); });
    $("quest-talk")?.addEventListener("click", () => {
      const npc = game.nearbyNpc;
      if (npc?.id === "village_elder") game.interactNpc(npc.id);
      else game.toast("守林村长位于新手村中央，返回村庄靠近他");
      openPanel(type);
    });
    $("quest-action")?.addEventListener("click", () => { if (!game.questAccepted) game.acceptQuest(); else game.claimQuest(); openPanel(type); });
    $("deepwood-accept")?.addEventListener("click", () => { game.acceptDeepwoodQuest(); openPanel(type); });
    $("deepwood-claim")?.addEventListener("click", () => { game.claimDeepwoodQuest(); openPanel(type); });
    $("settings-save")?.addEventListener("click", () => game.save());
    $("settings-exit")?.addEventListener("click", () => { game.save(); location.reload(); });
  }
}

showScreen("screen-login");
