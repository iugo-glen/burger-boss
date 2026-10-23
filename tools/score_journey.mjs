import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';

// Challenge input uses the same canvas controls as a player. Telemetry is
// read-only; completion and precise timer boundaries live in the Godot tests.
export async function runScoreJourney({page,tap,name}) {
  const read=()=>page.evaluate(()=>window.__burgerBoss);
  const wait=(predicate,arg,timeout=10000)=>page.waitForFunction(predicate,arg,{timeout});
  const shot=stage=>page.screenshot({path:`build/browser/${name}-score-${stage}.png`});
  const pause=async()=>{
    if(!(await read()).paused) await tap(662,50);
    await wait(()=>window.__burgerBoss.paused===true);
  };
  const choose=async()=>{
    await pause();
    await tap(360,818);
    await wait(()=>window.__burgerBoss.challenge.panel==='choose');
  };
  const career=state=>({money:state.money,sold:state.sold,elapsed:state.elapsed,upgrades:state.upgrades});
  try {
    await choose();
    const before=await read();
    assert.ok(before.sold>0,'challenge is tested with earned career progress');
    await shot('chooser');
    await tap(360,850);
    await wait(()=>window.__burgerBoss.challenge.panel==='');
    assert.deepEqual(career(await read()),career(before),'closing the chooser preserves the frozen career');
    await choose();
    await tap(360,556);
    await wait(()=>window.__burgerBoss.challenge.active && window.__burgerBoss.challenge.mode==='score_attack');
    const started=await read();
    assert.equal(started.sold,0,'score attack starts a fresh restaurant');
    assert.equal(started.money,0,'score attack starts with no gifted money');
    assert.deepEqual(started.career,career(before),'career is frozen behind the challenge');
    assert.ok(started.challenge.remaining>290 && started.challenge.remaining<=300,'score attack visibly counts down from five minutes');
    await tap(170,430);
    await wait(()=>window.__burgerBoss.carried>=3,null,20000);
    await tap(540,430);
    await wait(()=>window.__burgerBoss.challenge.score>0,null,20000);
    const scored=await read();
    assert.ok(scored.sold>0,'real service earns challenge points');
    assert.deepEqual(scored.career,started.career,'challenge service cannot change career money or sales');
    await shot('earned-points');
    await pause();
    const frozen=await read();
    await page.waitForTimeout(1200);
    const still=await read();
    assert.equal(still.challenge.elapsed,frozen.challenge.elapsed,'pause freezes challenge active time');
    assert.equal(still.challenge.score,frozen.challenge.score,'pause freezes scoring');
    await tap(360,818);
    await wait(()=>window.__burgerBoss.challenge.panel==='abandon');
    await shot('abandon-confirm');
    await tap(170,430);
    await tap(361,1019);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(650);
    assert.equal((await read()).challenge.panel,'abandon','abandonment requires an explicit confirmation');
    await tap(360,676);
    await wait(()=>window.__burgerBoss.challenge.panel==='');
    assert.ok((await read()).challenge.score>=frozen.challenge.score,'cancel abandonment keeps the run');
    if((await read()).paused) await tap(360,594);
    await wait(()=>window.__burgerBoss.paused===false);
    await wait(elapsed=>window.__burgerBoss.challenge.elapsed>elapsed+0.5,frozen.challenge.elapsed);
    let completed=null;
    let expectedRecords=before.challenge.records;
    if(name==='mobile-chromium' && process.env.SMOKE_SCORE_FINISH!=='0') {
      // Software-rendered CI browsers can advance active time slower than wall
      // time. Keep cooking until the real 300-second run ends, with a bounded
      // wall guard for a stalled browser; all completion assertions stay exact.
      const deadline=Date.now()+450000;
      let minute=-1;
      while(!(await read()).challenge.finished && Date.now()<deadline) {
        await tap(170,430);
        await page.waitForTimeout(5000);
        if((await read()).challenge.finished) break;
        await tap(540,430);
        await page.waitForTimeout(4000);
        const state=await read();
        if(Math.floor(state.challenge.elapsed/60)>minute) {
          minute=Math.floor(state.challenge.elapsed/60);
          console.log(`${name}: score attack ${minute}m, ${state.challenge.score} points`);
        }
      }
      await wait(()=>window.__burgerBoss.challenge.finished===true,null,10000);
      completed=await read();
      assert.equal(completed.challenge.elapsed,300,'a real score attack completes at five active minutes');
      assert.ok(completed.challenge.score>0,'a full run earns points through real cooking and serving');
      assert.ok(completed.challenge.record_saved,'the full run saves its personal best');
      assert.ok(completed.challenge.records.score_attack.best_score>=completed.challenge.score,'the result records a personal best');
      assert.ok(['None','Bronze','Silver','Gold'].includes(completed.challenge.result.medal),'the result reports its earned medal tier');
      assert.deepEqual(completed.career,started.career,'the full five-minute run leaves career untouched');
      expectedRecords=completed.challenge.records;
      await shot('complete');
      await tap(360,770);
      await wait(()=>window.__burgerBoss.challenge.finished===false && window.__burgerBoss.challenge.elapsed<5);
      assert.equal((await read()).challenge.score,0,'Play again starts a fresh score attack');
    }
    await pause();
    await tap(360,818);
    await wait(()=>window.__burgerBoss.challenge.panel==='abandon');
    await tap(360,788);
    await wait(()=>window.__burgerBoss.challenge.active===false);
    const returned=await read();
    assert.deepEqual(career(returned),career(before),'abandon restores career money, sales, equipment and clock exactly');
    assert.deepEqual(returned.challenge.records,expectedRecords,'an unfinished run sets no personal best');
    await choose();
    await tap(360,692);
    await wait(()=>window.__burgerBoss.challenge.active && window.__burgerBoss.challenge.mode==='speedrun');
    await wait(()=>window.__burgerBoss.challenge.elapsed>0.5);
    const speedrun=await read();
    assert.equal(speedrun.sold,0,'fastest-to-max also starts from a fresh restaurant');
    await shot('speedrun');
    await pause();
    await page.waitForTimeout(1200);
    await page.reload();
    await wait(()=>window.__burgerBoss?.challenge?.active===false,null,90000);
    await pause();
    const reloaded=await read();
    assert.ok(reloaded.money>=before.money,'refreshing a challenge preserves earned career money');
    assert.ok(reloaded.sold>=before.sold,'refreshing a challenge preserves earned career sales');
    assert.deepEqual(reloaded.upgrades,before.upgrades,'refreshing a challenge preserves career equipment');
    assert.deepEqual(reloaded.challenge.records,expectedRecords,'personal bests survive refresh and an unfinished run sets no record');
    await shot('career-restored');
    await tap(360,594);
    await wait(()=>window.__burgerBoss.paused===false);
    const report={before,started,scored,frozen,completed,returned,speedrun,reloaded};
    await writeFile(`build/browser/${name}-score-report.json`,JSON.stringify(report,null,2));
    return report;
  } catch(error) {
    await shot('failed-check');
    await writeFile(`build/browser/${name}-score-failed.json`,JSON.stringify(await read(),null,2));
    throw error;
  }
}
