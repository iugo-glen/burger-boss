import { chromium, webkit } from 'playwright';
import { createServer } from 'node:http';
import { readFile, stat, mkdir, writeFile } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import assert from 'node:assert/strict';
import { runRushJourney } from './rush_journey.mjs';
import { runResetJourney } from './reset_journey.mjs';

const root = resolve(process.env.WEB_ROOT || 'public');
const types = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml' };
const server = createServer(async (req, res) => {
  try {
    const file = resolve(root, '.' + decodeURIComponent(new URL(req.url, 'http://localhost').pathname));
    if (!file.startsWith(root + sep)) throw Error('Invalid path');
    const info = await stat(file);
    const target = info.isDirectory() ? resolve(file, 'index.html') : file;
    res.setHeader('Content-Type', types[extname(target)] || 'application/octet-stream');
    res.end(await readFile(target));
  } catch { res.writeHead(404).end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const url = `http://127.0.0.1:${server.address().port}/index.html?smoke=1`;
const reports = [];
await mkdir('build/browser', { recursive: true });
try {
  for (const [name, type, mobile] of [['desktop-chromium', chromium, false], ['mobile-chromium', chromium, true], ['mobile-webkit', webkit, true]].filter(([name])=>!process.env.SMOKE_ENGINES || process.env.SMOKE_ENGINES.split(',').includes(name))) {
    const browser = await type.launch({headless:true,args:type===chromium?['--no-sandbox','--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']:[]});
    try {
      const context = await browser.newContext({viewport:mobile?{width:390,height:844}:{width:1000,height:900},deviceScaleFactor:1,isMobile:mobile,hasTouch:mobile});
      const page = await context.newPage();
      const errors=[];
      page.on('pageerror', e=>errors.push(e.message));
      page.on('console', m=>{ if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text())) errors.push(m.text()); });
      await page.goto(url);
      await page.waitForFunction(()=>document.querySelector('canvas')?.width>0 && !document.querySelector('#status'),null,{timeout:90000});
      await page.screenshot({path:`build/browser/${name}.png`});
      if (process.env.SMOKE_BASELINE !== '1') {
        await page.waitForFunction(()=>window.__burgerBoss?.sold!==undefined,null,{timeout:15000});
        const initial=await page.evaluate(()=>window.__burgerBoss);
        assert.equal(initial.sold,0,'fresh context starts at zero sales');
        const pointAt=async(x,y)=>{
          const rect=await page.locator('canvas').boundingBox();
          const factor=Math.min(rect.width/720,rect.height/1280);
          return {x:rect.x+(rect.width-720*factor)/2+x*factor,y:rect.y+(rect.height-1280*factor)/2+y*factor};
        };
        const tap=async(x,y)=>{
          const point=await pointAt(x,y);
          if(mobile) await page.touchscreen.tap(point.x,point.y); else await page.mouse.click(point.x,point.y);
        };
        // All navigation and dismissal assertions use real canvas controls.
        assert.equal(initial.guide_visible,true,'fresh players see the tutorial');
        await tap(250,311); // Optional promotion explains its fresh-save unlock.
        await page.waitForFunction(()=>/25/.test(window.__burgerBoss.notice_text),null,{timeout:5000});
        const lockedRush=await page.evaluate(()=>window.__burgerBoss);
        assert.equal(lockedRush.rush.active,false,'fresh promotion stays locked');
        assert.equal(lockedRush.money,0,'checking a promotion never costs money');
        await tap(361,1019); // Persistent, labelled Hire staff tab.
        await page.waitForFunction(()=>window.__burgerBoss.menu==='staff');
        await page.screenshot({path:`build/browser/${name}-hire-tab.png`});
        await tap(185,1113); // Insufficient funds must produce a dismissible notice.
        await page.waitForFunction(()=>window.__burgerBoss.notice_visible===true && /Need|enough/i.test(window.__burgerBoss.notice_text));
        assert.match(await page.evaluate(()=>window.__burgerBoss.notice_text),/Need|enough/i);
        await tap(656,933);
        await page.waitForFunction(()=>window.__burgerBoss.notice_visible===false);
        await tap(185,1113); // Repeating the same message must still show it again.
        await page.waitForFunction(()=>window.__burgerBoss.notice_visible===true);
        await page.waitForFunction(()=>window.__burgerBoss.notice_visible===false,null,{timeout:7000});
        await tap(595,1019);
        await page.waitForFunction(()=>window.__burgerBoss.menu==='expand');
        await tap(127,1019);
        await page.waitForFunction(()=>window.__burgerBoss.menu==='upgrades');
        await tap(660,215); // Tutorial X.
        await page.waitForFunction(()=>window.__burgerBoss.guide_visible===false);
        await tap(478,48); // Help restores dismissed guidance.
        await page.waitForFunction(()=>window.__burgerBoss.guide_visible===true);
        await tap(660,215);
        await page.waitForFunction(()=>window.__burgerBoss.guide_visible===false);
        await tap(660,215); // A closed guide must not leave an invisible click blocker.
        await page.waitForFunction(x=>window.__burgerBoss.player.x>x+20,initial.player.x,{timeout:5000});
        await tap(170,430);
        await page.waitForFunction(()=>window.__burgerBoss.carried>=3,null,{timeout:20000});
        await tap(540,430);
        await page.waitForFunction(()=>window.__burgerBoss.sold>0,null,{timeout:20000});
        const first=await page.evaluate(()=>window.__burgerBoss);
        assert.ok(first.elapsed<60,'first burger is served within 60 seconds');
        await page.waitForFunction(()=>window.__burgerBoss.money>=35,null,{timeout:15000});
        await tap(595,1113); // Speed upgrade, purchased with earned cash.
        try { await page.waitForFunction(()=>window.__burgerBoss.upgrades.speed===1,null,{timeout:5000}); } catch(error) { console.log(await page.evaluate(()=>window.__burgerBoss)); await page.screenshot({path:`build/browser/${name}-failed.png`}); throw error; }
        const purchased=await page.evaluate(()=>window.__burgerBoss);
        await page.screenshot({path:`build/browser/${name}-played.png`});
        // Save through the real pause/focus path, then reload the same persistent browser context.
        await page.keyboard.press('Escape');
        await page.waitForTimeout(1200);
        await page.reload();
        await page.waitForFunction(()=>window.__burgerBoss?.sold>0,null,{timeout:90000});
        const restored=await page.evaluate(()=>window.__burgerBoss);
        assert.equal(restored.sold,purchased.sold,'sales survive browser reload');
        assert.equal(restored.money,purchased.money,'money survives browser reload');
        assert.equal(restored.upgrades.speed,1,'upgrade survives browser reload');
        assert.equal(restored.guide_visible,false,'dismissed tutorial stays closed after reload');
        await tap(478,48);
        await page.waitForFunction(()=>window.__burgerBoss.guide_visible===true);
        await tap(660,215);
        await page.waitForFunction(()=>window.__burgerBoss.guide_visible===false);
        await tap(662,50);
        await page.waitForFunction(()=>window.__burgerBoss.paused===true);
        const frozen=await page.evaluate(()=>window.__burgerBoss.elapsed);
        await page.waitForTimeout(1200);
        assert.equal(await page.evaluate(()=>window.__burgerBoss.elapsed),frozen,'paused simulation time stays frozen');
        await tap(662,50);
        await page.waitForFunction(()=>window.__burgerBoss.paused===false);
        if (!mobile) {
          const before=await page.evaluate(()=>window.__burgerBoss.player.x);
          await page.keyboard.down('a'); await page.waitForTimeout(600); await page.keyboard.up('a');
          await page.waitForTimeout(700);
          const after=await page.evaluate(()=>window.__burgerBoss.player.x);
          assert.ok(after<before-20,'WASD moves the player');
          await page.waitForTimeout(800);
          assert.ok(Math.abs((await page.evaluate(()=>window.__burgerBoss.player.x))-after)<3,'key release stops movement');
        }
        if (mobile && type===chromium) {
          const session=await context.newCDPSession(page);
          const before=await page.evaluate(()=>window.__burgerBoss.player.x);
          const start=await pointAt(350,760), end=await pointAt(250,760);
          await session.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...start,id:0}]});
          await session.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{...end,id:0}]});
          await page.waitForTimeout(600);
          await session.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
          await page.waitForTimeout(700);
          const stopped=await page.evaluate(()=>window.__burgerBoss.player.x);
          assert.ok(stopped<before-20,'touch joystick drag moves the player');
          await page.waitForTimeout(800);
          assert.ok(Math.abs((await page.evaluate(()=>window.__burgerBoss.player.x))-stopped)<3,'touch release stops movement');
          await session.detach();
        }
        let earnedHire=null;
        if (name==='mobile-chromium') {
          // Earn the hire entirely through touch play, with no injected model state.
          for (let batch=0; batch<5 && (await page.evaluate(()=>window.__burgerBoss.money))<90; batch++) {
            await tap(170,430);
            await page.waitForFunction(()=>window.__burgerBoss.carried>=3,null,{timeout:20000});
            const sales=await page.evaluate(()=>window.__burgerBoss.sold);
            await tap(540,430);
            await page.waitForFunction(sold=>window.__burgerBoss.sold>=sold+3,sales,{timeout:20000});
          }
          const cash=await page.evaluate(()=>window.__burgerBoss.money);
          assert.ok(cash>=90,'manual serving earns enough to hire a cook');
          await tap(361,1019);
          await page.waitForFunction(()=>window.__burgerBoss.menu==='staff');
          await tap(185,1113);
          await page.waitForFunction(()=>window.__burgerBoss.upgrades.cook===1);
          earnedHire=await page.evaluate(()=>window.__burgerBoss);
          assert.equal(earnedHire.money,cash-90,'touch hire spends the earned $90');
          await page.screenshot({path:`build/browser/${name}-hired-cook.png`});
          await tap(127,1019);
          await page.waitForFunction(()=>window.__burgerBoss.menu==='upgrades');
        }
        const rushJourney=name==='mobile-chromium' && process.env.SMOKE_RUSH!=='0'
          ? await runRushJourney({page,tap,name}) : null;
        const soakSeconds=Number(process.env.SMOKE_SECONDS||0);
        if(soakSeconds>0){
          // Continue performing real user input; no model state is injected.
          const deadline=Date.now()+soakSeconds*1000;
          while(Date.now()<deadline){
            await tap(170,430); await page.waitForTimeout(4800);
            await tap(540,430); await page.waitForTimeout(4200);
          }
          assert.ok((await page.evaluate(()=>window.__burgerBoss.sold))>restored.sold,'soak continues serving');
        }
        const resetJourney=await runResetJourney({page,tap,name,initial});
        reports.push({name,firstSaleSeconds:first.elapsed,restored,earnedHire,rushJourney,resetJourney,soakSeconds,final:await page.evaluate(()=>window.__burgerBoss),errors});
      } else {
        await page.waitForTimeout(5000);
        reports.push({name,loaded:true,errors});
      }
      assert.deepEqual(errors,[],`${name}: no runtime errors`);
      console.log(`${name}: passed`);
      await context.close();
    } finally { await browser.close(); }
  }
  await writeFile(process.env.SMOKE_REPORT || 'build/browser/report.json',JSON.stringify(reports,null,2));
} finally { await new Promise(resolve=>server.close(resolve)); }
