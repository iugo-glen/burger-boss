import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';

const modelKeys=['elapsed','money','sold','lost','player','carried','fries_carried','grill_stock','counter_stock','fries_stock','counter_fries','combo_served','boss_actions','boss_cooldown','upgrades','staff','queue','rush'];
const checkpoint=state=>Object.fromEntries(modelKeys.map(key=>[key,state[key]]));

// Every action goes through real canvas input. Existing progression is earned
// by the smoke journey; no save fixtures or model commands are injected.
export async function runResetJourney({page,tap,name,initial}) {
  const read=()=>page.evaluate(()=>window.__burgerBoss);
  const wait=(predicate,arg,timeout=10000)=>page.waitForFunction(predicate,arg,{timeout});
  const shot=stage=>page.screenshot({path:`build/browser/${name}-reset-${stage}.png`});
  const pause=async()=>{
    if(!(await read()).paused) await tap(662,50);
    await wait(()=>window.__burgerBoss.pause_menu_visible===true);
  };
  const open=async()=>{
    await pause();
    await tap(360,706);
    await wait(()=>window.__burgerBoss.reset_confirm_visible===true);
  };
  const startEarnedRush=async()=>{
    const state=await read();
    if(!state.paused && state.rush_lock_reason==='') {
      await tap(250,311);
      await wait(()=>window.__burgerBoss.rush.active===true);
      return true;
    }
    return false;
  };
  const assertFresh=state=>{
    assert.equal(state.money,0,'start over clears money');
    assert.equal(state.sold,0,'start over clears sales');
    assert.equal(state.lost,0,'start over clears lost customers');
    assert.deepEqual(state.upgrades,initial.upgrades,'start over restores the starting equipment');
    assert.equal(state.staff.length,0,'start over removes all hired workers');
    for(const key of ['carried','fries_carried','grill_stock','counter_stock','fries_stock','counter_fries','combo_served','boss_actions']) {
      assert.equal(state[key],0,`start over clears ${key}`);
    }
    for(const key of ['rank','wins','best','reward','served','combos','specials']) {
      assert.equal(state.rush[key],0,`start over clears rush ${key}`);
    }
    assert.equal(state.rush.active,false,'start over stops an active promotion');
    assert.equal(state.guide_visible,true,'start over restores the tutorial');
    assert.equal(state.muted,true,'start over preserves the sound preference');
    assert.equal(state.reset_confirm_visible,false,'confirmation closes after successful reset');
    assert.equal(state.paused,false,'the fresh restaurant can be played immediately');
    assert.deepEqual(state.player,initial.player,'start over restores the starting player position');
  };
  try {
    assert.ok((await read()).sold>0,'reset is tested after actual earned progression');
    if(!(await read()).muted) await tap(584,50);
    await wait(()=>window.__burgerBoss.muted===true);
    const cancelledActiveRush=await startEarnedRush();
    await open();
    const frozen=await read();
    await shot('confirmation');
    // The dialog must not let the header, world, upgrades or movement keys act
    // on the game beneath it. Enter/Space must not replace the red confirmation.
    await tap(170,430);
    await tap(361,1019);
    await tap(596,311);
    await tap(662,50);
    await page.keyboard.down('a');
    await page.waitForTimeout(400);
    await page.keyboard.up('a');
    await page.keyboard.press('Enter');
    await page.keyboard.press('Space');
    await page.waitForTimeout(1000);
    const blocked=await read();
    assert.equal(blocked.reset_confirm_visible,true,'only explicit dialog actions close the modal');
    assert.equal(blocked.menu,frozen.menu,'the modal blocks underlying tab clicks');
    assert.deepEqual(checkpoint(blocked),checkpoint(frozen),'modal gameplay, staff and rush clocks stay frozen');
    await page.keyboard.press('Escape');
    await wait(()=>window.__burgerBoss.reset_confirm_visible===false);
    const escaped=await read();
    assert.equal(escaped.pause_menu_visible,true,'Escape cancels the dialog while staying paused');
    assert.deepEqual(checkpoint(escaped),checkpoint(frozen),'Escape preserves every live gameplay field');
    await open();
    await tap(360,696); // Cancel, distinct from the destructive red button.
    await wait(()=>window.__burgerBoss.reset_confirm_visible===false);
    const cancelled=await read();
    assert.equal(cancelled.pause_menu_visible,true,'cancel returns to the paused menu');
    assert.deepEqual(checkpoint(cancelled),checkpoint(frozen),'cancel leaves every live gameplay field untouched');
    await page.reload();
    await wait(()=>window.__burgerBoss?.sold>0,null,90000);
    const cancelledReload=await read();
    assert.deepEqual(cancelledReload.upgrades,cancelled.upgrades,'cancel preserves purchased upgrades on reload');
    assert.equal(cancelledReload.staff.length,cancelled.staff.length,'cancel preserves hired staff on reload');
    assert.equal(cancelledReload.rush.rank,cancelled.rush.rank,'cancel preserves restaurant rank on reload');
    assert.ok(cancelledReload.money>=cancelled.money,'cancel never removes earned money');
    assert.ok(cancelledReload.sold>=cancelled.sold,'cancel never removes earned sales');
    assert.equal(cancelledReload.guide_visible,cancelled.guide_visible,'cancel preserves the help preference');
    assert.equal(cancelledReload.muted,true,'cancel preserves the sound preference on reload');
    const confirmedActiveRush=await startEarnedRush();
    await open();
    const beforeConfirmation=await read();
    assert.ok(beforeConfirmation.sold>0,'opening the modal alone never resets progress');
    await page.keyboard.down('d'); // Holding movement must not leak into the new game.
    await tap(360,816); // Explicit red Erase & start over button.
    await wait(()=>window.__burgerBoss.reset_confirm_visible===false && window.__burgerBoss.sold===0);
    await page.waitForTimeout(900);
    const fresh=await read();
    assertFresh(fresh);
    await page.keyboard.up('d');
    await wait(()=>window.__burgerBoss.keyboard_release_pending===false);
    await shot('fresh');
    // Reload immediately after confirmation: the durable reset must win over
    // any previous autosave or active-rush snapshot.
    await page.waitForTimeout(1200);
    await page.reload();
    await wait(()=>window.__burgerBoss?.sold===0,null,90000);
    const freshReload=await read();
    assertFresh(freshReload);
    await shot('fresh-reloaded');
    await tap(170,430);
    await wait(()=>window.__burgerBoss.carried>0,null,20000);
    await tap(540,430);
    await wait(()=>window.__burgerBoss.sold===1,null,20000);
    const restarted=await read();
    assert.equal(restarted.money,12,'the reset restaurant starts earning normally without stale bonuses');
    assert.equal(restarted.staff.length,0,'no old workers return after the first fresh sale');
    await page.waitForTimeout(9000); // Cross the fresh eight-second autosave boundary.
    await page.reload();
    await wait(()=>window.__burgerBoss?.sold!==undefined,null,90000);
    const autosavedReload=await read();
    assert.equal(autosavedReload.sold,1,'later autosave cannot resurrect the previous restaurant');
    assert.equal(autosavedReload.money,12,'the new restaurant cash survives its own autosave');
    assert.deepEqual(autosavedReload.upgrades,initial.upgrades,'old upgrades never return after autosave');
    assert.equal(autosavedReload.staff.length,0,'old workers never return after autosave');
    assert.equal(autosavedReload.rush.rank,0,'old rank never returns after autosave');
    assert.equal(autosavedReload.muted,true,'the sound preference remains after the new autosave');
    const report={cancelledActiveRush,confirmedActiveRush,frozen,escaped,cancelled,cancelledReload,beforeConfirmation,fresh,freshReload,restarted,autosavedReload};
    await writeFile(`build/browser/${name}-reset-report.json`,JSON.stringify(report,null,2));
    return report;
  } catch(error) {
    await shot('failed-check');
    await writeFile(`build/browser/${name}-reset-failed.json`,JSON.stringify(await read(),null,2));
    throw error;
  }
}
