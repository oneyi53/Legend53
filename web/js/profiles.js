// Local single-player profiles. No server, no password storage.
// One active character per device: the world save is a single slot, so creating
// a new character overwrites it (confirmed in the UI before doing so).
const PROFILES_KEY = "legend53-profiles-v1";
const ACTIVE_KEY = "legend53-active-profile-v1";
const ACCOUNT_KEY = "legend53-account";

const SURNAMES = ["沈", "顾", "林", "萧", "楚", "陆", "江", "白", "秦", "苏", "叶", "韩"];
const GIVEN = ["长风", "秋", "云深", "子衿", "望舒", "清寒", "如风", "夜白", "千帆", "慕雪", "辰", "若离"];

export function randomName() {
  const s = SURNAMES[Math.floor(Math.random() * SURNAMES.length)];
  const g = GIVEN[Math.floor(Math.random() * GIVEN.length)];
  return s + g;
}

function read(key) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : null;
  } catch (e) {
    return null;
  }
}
function write(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
    return true;
  } catch (e) {
    return false;
  }
}

export function listProfiles() {
  const list = read(PROFILES_KEY);
  return Array.isArray(list) ? list : [];
}
export function getActiveProfile() {
  const id = read(ACTIVE_KEY);
  return listProfiles().find((p) => p.id === id) || null;
}
export function getRememberedAccount() {
  try {
    return localStorage.getItem(ACCOUNT_KEY) || "";
  } catch (e) {
    return "";
  }
}
export function rememberAccount(account) {
  try {
    localStorage.setItem(ACCOUNT_KEY, account || "");
  } catch (e) { /* ignore */ }
}
export function createProfile({ name, classId, gender }) {
  const profile = {
    id: "char-" + Date.now().toString(36),
    name: (name || "").trim() || randomName(),
    classId,
    gender: gender === "女" ? "女" : "男",
    createdAt: Date.now(),
  };
  write(PROFILES_KEY, [profile]);
  write(ACTIVE_KEY, profile.id);
  return profile;
}
export function setActiveProfile(id) {
  write(ACTIVE_KEY, id);
}
export function deleteActiveProfile() {
  write(PROFILES_KEY, []);
  try {
    localStorage.removeItem(ACTIVE_KEY);
  } catch (e) { /* ignore */ }
}
