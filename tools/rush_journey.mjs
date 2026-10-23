import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';

// The entire progression uses browser touch input. Telemetry is read-only;
// no save fixture, gifted currency, or JavaScript model commands are used here.
export async function runRushJourney({page,tap,name}) {
  const read=()=>page.evaluate(()=>window.__burgerBoss);
  const shot=stage=>page.screenshot({path:`build/browser/${name}-rush-${stage}.png`});
  const wait=(predicate,arg,timeout=20000)=>page.waitForFunction(predicate,arg,{timeout});
  const walk=async(x,y)=>{
    await tap(x,y);
    await wait(({x,y})=>Math.hypot(window.__burgerBoss.player.x-x,window.__burgerBoss.player.y-y)<95,{x,y});
  };
  const earn=async(goal)=>{
    for(let batch=0;batch<20 && (await read()).money<goal;batch++) {
      const start=await read();
      await walk(170,430);
      await wait(()=>window.__burgerBoss.carried>=3);
      await walk(540,430);
      await wait(sold=>window.__burgerBoss.sold>=sold+3,start.sold);
    }
    assert.ok((await read()).money>=goal,`touch service earns $${goal}`);
  };
  const menu=async(id)=>{
    const x={upgrades:127,staff:361,expand:595}[id];
    await tap(x,1019);
    await wait(expected=>window.__burgerBoss.menu===expected,id,5000);
  };
  const buy=async(id,x,y)=>{
    const before=await read();
    await tap(x,y);
    await wait(({id,level})=>window.__burgerBoss.upgrades[id]===level+1,{id,level:before.upgrades[id]},5000);
    assert.ok((await read()).money<before.money,`${id} spends earned currency`);
  };
  const assign=async(role,wanted,x)=>{
    for(let click=0;click<4;click++) {
      const workers=(await read()).staff.filter(worker=>worker.role===role);
      assert.ok(workers.length>0,`${role} exists before assignment`);
      if(workers.every(worker=>worker.assignment===wanted)) return;
      await tap(x,1201);
      await page.waitForTimeout(650);
    }
    assert.fail(`${role} assignment did not reach ${wanted}`);
  };
  try {
    // Existing basic smoke has already earned and hired one cook.
    assert.equal((await read()).upgrades.cook,1);
    await earn(120);
    await menu('staff');
    await buy('cashier',535,1113);
    await earn(180);
    await menu('expand');
    await buy('fries',361,1156);
    const unlocked=await read();
    assert.ok(unlocked.sold>=25,'the promotion unlock is earned through actual sales');
    await menu('staff');
    await assign('cook','fries',185);
    await assign('cashier','counter',535);
    await shot('assignments');

    // Prepare each stock through physical work; assignment cannot create food
    // in the counter without a worker completing a real station trip.
    await walk(170,430);
    await tap(596,311);
    await wait(()=>window.__burgerBoss.carried>=3);
    await walk(540,430);
    await page.waitForTimeout(1100);
    await walk(170,660);
    await tap(596,311);
    await wait(()=>window.__burgerBoss.fries_carried>=2);
    await walk(540,430);
    await page.waitForTimeout(1100);
    const beforeRush=await read();
    await tap(250,311);
    await wait(()=>window.__burgerBoss.rush.active===true,null,5000);
    await wait(()=>window.__burgerBoss.queue.some(customer=>customer.combo && customer.rush_order),null,10000);
    const started=await read();
    await shot('started');

    // Deliberately use a simple, repeatable boss route rather than perfect
    // action timing. The player cooks, fries, carries and boosts real orders.
    const end=Date.now()+95000;
    const workerWitnesses=[];
    while((await read()).rush.active && Date.now()<end) {
      await walk(170,430);
      await tap(596,311);
      await wait(()=>!window.__burgerBoss.rush.active || window.__burgerBoss.carried>=3,null,12000);
      if(!(await read()).rush.active) break;
      const supplies=await read();
      // The assigned cook handles sides. Help at that station only when the
      // visible counter supply gets low, then return to the burger job.
      if(supplies.counter_fries<3 && supplies.fries_carried<2) {
        await walk(170,660);
        await tap(596,311);
        await wait(()=>!window.__burgerBoss.rush.active || window.__burgerBoss.fries_carried>=2,null,12000);
      }
      if(!(await read()).rush.active) break;
      await walk(540,430);
      await tap(596,311);
      await page.waitForTimeout(2000);
      const observed=await read();
      workerWitnesses.push(...observed.staff.filter(worker=>worker.role==='cook').map(worker=>({state:worker.state,assignment:worker.assignment,carry_kind:worker.carry_kind,trips:worker.trips,position:worker.position})));
      if(observed.rush.active && observed.rush.specials>0) await shot('active-handoff');
    }
    const success=await read();
    assert.equal(success.rush.active,false,'rush timer finishes');
    assert.equal(success.rush.result,'Success','active station work completes the promotion');
    assert.ok(success.rush.wins>beforeRush.rush.wins,'successful promotion records a win');
    assert.ok(success.rush.rank>beforeRush.rush.rank,'successful promotion increases restaurant rank');
    assert.ok(success.rush.reward>0,'successful promotion awards a cash bonus');
    assert.ok(success.rush.combos>=success.rush.combo_goal,'the goal includes completed burger-and-fries orders');
    assert.ok(success.rush.specials>=success.rush.special_goal,'physical counter visits hand off the boss-special combos');
    assert.ok(success.combo_served>beforeRush.combo_served,'real combo customers are served');
    assert.ok(success.boss_actions>beforeRush.boss_actions,'station buttons perform real boss actions');
    assert.ok(workerWitnesses.some(worker=>worker.assignment==='fries' && /fries|frying/.test(worker.state)),'assigned cook visibly works at the fries job');
    const cookBefore=beforeRush.staff.find(worker=>worker.role==='cook');
    const cookAfter=success.staff.find(worker=>worker.role==='cook');
    assert.ok(cookAfter.trips>cookBefore.trips,'assigned cook completes physical ingredient delivery trips');
    await shot('success');

    // Keep the cook on sides and leave the burger grill unattended. The second
    // promotion must resolve safely without a permanent blocked queue.
    await walk(50,900);
    await tap(250,311);
    await wait(()=>window.__burgerBoss.rush.active===true,null,5000);
    await wait(()=>window.__burgerBoss.rush.active===false,null,95000);
    const failure=await read();
    assert.equal(failure.rush.result,'Try again','ignoring the burger job loses the promotion');
    assert.equal(failure.rush.wins,success.rush.wins,'failure does not grant a win');
    assert.equal(failure.rush.reward,0,'a failed promotion grants no challenge bonus');
    assert.ok(failure.money>=success.money,'failing a promotion never removes earned cash');
    await shot('failure');
    await tap(250,311);
    await wait(()=>window.__burgerBoss.rush.active===true,null,5000);
    const retry=await read();
    assert.ok(retry.money>=failure.money,'retry never charges the player');
    // Reloading an active optional rush cancels it safely while keeping the
    // naturally earned staff, stock and rank. No fixture is seeded.
    await page.keyboard.press('Escape');
    await page.waitForTimeout(1200);
    await page.reload();
    await wait(()=>window.__burgerBoss?.rush!==undefined,null,90000);
    const recovered=await read();
    assert.equal(recovered.rush.active,false,'reload leaves optional timed play safely stopped');
    assert.equal(recovered.rush.rank,success.rush.rank,'rank survives interrupted promotion reload');
    assert.equal(recovered.upgrades.cook,1,'earned cook survives interrupted promotion reload');
    assert.equal(recovered.upgrades.cashier,1,'earned cashier survives interrupted promotion reload');
    assert.equal(recovered.upgrades.fries,1,'earned fries station survives interrupted promotion reload');
    assert.equal(recovered.staff.find(worker=>worker.role==='cook').assignment,'fries','cook assignment survives reload');
    assert.equal(recovered.staff.find(worker=>worker.role==='cashier').assignment,'counter','cashier assignment survives reload');
    await shot('recovered');
    const report={unlocked,beforeRush,started,workerWitnesses,success,failure,retry,recovered};
    await writeFile(`build/browser/${name}-rush-report.json`,JSON.stringify(report,null,2));
    return report;
  } catch(error) {
    await shot('failed-check');
    await writeFile(`build/browser/${name}-rush-failed.json`,JSON.stringify(await read(),null,2));
    throw error;
  }
}
