import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';

// This follows the existing reset journey's single earned sale. Only canvas
// controls change the game; telemetry is read to observe real customer behaviour.
export async function runPatienceJourney({page,tap,name}) {
  const read=()=>page.evaluate(()=>window.__burgerBoss);
  const wait=(predicate,arg,timeout=10000)=>page.waitForFunction(predicate,arg,{timeout});
  const shot=stage=>page.screenshot({path:`build/browser/${name}-patience-${stage}.png`});
  try {
    const initial=await read();
    assert.equal(initial.sold,1,'patience journey begins after one genuinely earned career sale');
    assert.equal(initial.lost,0,'the reset career has no lost customers');
    assert.equal(initial.staff.length,0,'no staff can serve during the unattended test');
    assert.equal(initial.calm_patience,45,'fresh career patience is a generous 45 seconds');
    assert.ok(initial.calm_arrivals_per_minute>18,'the earned sale grows calm demand');
    assert.ok(Math.abs(initial.calm_arrival_gap*initial.calm_arrivals_per_minute-60)<0.001,'arrival telemetry uses the demand curve');
    assert.equal(initial.queue_capacity,8,'fresh demand fits the initial queue');
    if(initial.guide_visible) await tap(660,215);
    await tap(350,800);
    await wait(()=>Math.abs(window.__burgerBoss.player.x-350)<5 && Math.abs(window.__burgerBoss.player.y-800)<5);
    // Catch an arrival in transit, then compare consecutive telemetry samples
    // that both precede reaching its queue position.
    let walkingBefore,walkingAfter;
    const deadline=Date.now()+18000;
    while(Date.now()<deadline) {
      const state=await read();
      const customer=state.queue.find(customer=>!customer.settled && customer.patience===customer.max_patience);
      if(customer) {
        await page.waitForTimeout(650);
        const next=(await read()).queue.find(next=>next.id===customer.id);
        if(next && !next.settled) { walkingBefore=customer; walkingAfter=next; break; }
      }
      await page.waitForTimeout(150);
    }
    assert.ok(walkingBefore,'observe an actual customer walking to the queue');
    assert.equal(walkingAfter.patience,walkingBefore.patience,'walking does not consume calm patience');
    await wait(id=>window.__burgerBoss.queue.some(customer=>customer.id===id && customer.settled),walkingBefore.id);
    const settledBefore=(await read()).queue.find(customer=>customer.id===walkingBefore.id);
    await page.waitForTimeout(1200);
    const settledAfter=(await read()).queue.find(customer=>customer.id===walkingBefore.id);
    assert.ok(settledAfter?.settled,'the observed customer stays at its queue position');
    assert.ok(settledAfter.patience<settledBefore.patience-0.5,'settled calm customers lose patience');
    const unattended=await read();
    await wait(()=>window.__burgerBoss.queue.some(customer=>customer.settled && customer.patience/customer.max_patience<0.2),null,60000);
    await shot('low');
    await wait(()=>window.__burgerBoss.lost>0 && window.__burgerBoss.departing_customers.length>0 && /left hungry/i.test(window.__burgerBoss.notice_text),null,20000);
    const departed=await read();
    assert.equal(departed.money,unattended.money,'a hungry departure earns no money');
    assert.equal(departed.sold,unattended.sold,'a hungry departure is never counted as a sale');
    assert.ok(departed.departing_customers.every(customer=>!departed.queue.some(queued=>queued.id===customer.id)),'departing customers leave the live queue');
    await shot('departure');
    await tap(662,50); // Pause also saves the career through its normal UI path.
    await wait(()=>window.__burgerBoss.paused===true);
    const saved=await read();
    await page.waitForTimeout(1200);
    assert.deepEqual((await read()).departing_customers,saved.departing_customers,'paused departure animation stays frozen');
    await page.reload();
    await wait(()=>window.__burgerBoss?.sold===1,null,90000);
    const restored=await read();
    assert.equal(restored.lost,saved.lost,'lost customers survive a browser reload');
    assert.equal(restored.money,saved.money,'departure cannot create reload income');
    assert.deepEqual(restored.departing_customers,[],'reloading clears transient departure art');
    await shot('reloaded');
    if(!restored.paused) await tap(662,50);
    await wait(()=>window.__burgerBoss.pause_menu_visible===true);
    await tap(360,706);
    await wait(()=>window.__burgerBoss.reset_confirm_visible===true);
    await tap(360,816);
    await wait(()=>window.__burgerBoss.sold===0 && window.__burgerBoss.reset_confirm_visible===false);
    assert.equal((await read()).lost,0,'confirmed reset clears the persisted lost counter');
    // Match the reset journey's normal browser filesystem flush boundary before
    // loading a second page into the same persistent context.
    await page.waitForTimeout(1200);
    await page.reload();
    await wait(()=>window.__burgerBoss?.sold===0,null,90000);
    const fresh=await read();
    assert.equal(fresh.lost,0,'lost customers remain cleared after reset and reload');
    assert.deepEqual(fresh.departing_customers,[],'reset clears transient departure art');
    await shot('reset');
    const report={initial,walkingBefore,walkingAfter,settledBefore,settledAfter,unattended,departed,saved,restored,fresh};
    await writeFile(`build/browser/${name}-patience-report.json`,JSON.stringify(report,null,2));
    return report;
  } catch(error) {
    await shot('failed-check');
    await writeFile(`build/browser/${name}-patience-failed.json`,JSON.stringify(await read(),null,2));
    throw error;
  }
}
