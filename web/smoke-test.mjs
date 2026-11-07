import { chromium } from "playwright";
import assert from "node:assert/strict";
import fs from "node:fs";

const browser = await chromium.launch({ headless: true, args: ["--no-sandbox"] });
const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
const errors = [];
page.on("pageerror", error => errors.push(error.message));
try {
  await page.goto("http://127.0.0.1:8000/", { waitUntil: "networkidle" });
  await page.waitForSelector("#world");
  await page.waitForTimeout(900);
  assert.equal(await page.title(), "HERO WORLD · 遗忘森林");
  assert.equal(await page.locator("#world").evaluate(el => el.width), 720);
  assert.equal(await page.locator("#world").evaluate(el => el.height), 1280);
  await page.locator('[data-panel="character"]').click();
  assert.equal(await page.locator("#modal").evaluate(el => !el.classList.contains("hidden")), true);
  await page.locator('[data-class="mage"]').click();
  assert.match(await page.locator("#portrait").getAttribute("src"), /mage\.svg$/);
  await page.locator("#modal-close").click();
  await page.locator("#auto-button").click();
  assert.equal(await page.locator("#auto-button").evaluate(el => el.classList.contains("active")), true);
  await page.locator("#quest-open").click();
  await page.locator('[data-quest="1"]').click();
  assert.match(await page.locator("#quest-progress").textContent(), /击败森林劫掠者/);
  await page.screenshot({ path: "artifacts/html5-browser/portrait-gameplay.png", fullPage: true });
  assert.deepEqual(errors, []);
  console.log("HTML5 browser smoke test passed");
} finally {
  await browser.close();
}
