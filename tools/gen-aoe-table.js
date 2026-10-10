// Builds Range Lens's AOE_RADIUS table: spells that hit an area around the
// caster (or a cone in front), from the game's own spell data.
//
// 1. Download these tables from wago.tools for the build (here 1.60.1.70009) into
//    this folder, as CSV (https://wago.tools/db2/<Table>/csv?build=<build>):
//    SpellName -> names.csv, SpellRadius -> radius.csv, SpellRange -> range.csv,
//    SpellMisc -> misc.csv, SkillLineAbility -> sla.csv, SkillLine -> skillline.csv,
//    and SpellEffect filtered by ImplicitTarget_0 = 22, 18, 24 and 1
//    (&filter%5BImplicitTarget_0%5D=<n>) -> se22.csv, se18.csv, se24.csv, se1.csv.
// 2. node gen-aoe-table.js > aoe.json, then copy the names and radii into AOE_RADIUS and CONE
//    in RangeLens.lua. Names ending in " Effect" are the pulses of other spells
//    (Hellfire Effect) and are left out.
const csv = require('./parse.js');
const names = Object.fromEntries(csv('names.csv').map(r => [r.ID, r.Name_lang]));
const radius = Object.fromEntries(csv('radius.csv').map(r => [r.ID, +r.Radius]));
const ranges = Object.fromEntries(csv('range.csv').map(r => [r.ID, Math.max(+r.RangeMax_0, +r.RangeMax_1)]));
const misc = {}; for (const r of csv('misc.csv')) misc[r.SpellID] = r;
// Spells players learn: on a class skill line (SkillLine CategoryID 7 = class).
const classLines = new Set(csv('skillline.csv').filter(r => r.CategoryID === '7').map(r => r.ID));
const learned = new Set(csv('sla.csv').filter(r => classLines.has(r.SkillLine)).map(r => r.Spell));
const effects = [...csv('se22.csv'), ...csv('se18.csv'), ...csv('se24.csv'), ...csv('se1.csv')];
const bySpell = {}; for (const e of effects) (bySpell[e.SpellID] = bySpell[e.SpellID] || []).push(e);

const ENEMY_AREA = new Set(['15', '16']);   // UNIT_SRC_AREA_ENEMY, UNIT_DEST_AREA_ENEMY
function areaOf(spellID, depth) {
  let best = null;
  for (const e of bySpell[spellID] || []) {
    const a = e.ImplicitTarget_0, b = e.ImplicitTarget_1;
    const rIdx = +e.EffectRadiusIndex_1 || +e.EffectRadiusIndex_0;
    let kind = null;
    if (a === '22' && ENEMY_AREA.has(b)) kind = 'around';          // centered on you
    else if (a === '18' && ENEMY_AREA.has(b)) kind = 'around';      // at your feet
    else if (a === '24') kind = 'cone';                              // cone in front of you
    if (kind && rIdx && radius[rIdx]) {
      const r = radius[rIdx];
      if (!best || r < best.r) best = { r, kind };
    }
    // A channel or aura on you that pulses another spell (Hellfire).
    if (!kind && a === '1' && e.EffectTriggerSpell !== '0' && depth < 2) {
      const child = areaOf(e.EffectTriggerSpell, depth + 1);
      if (child && (!best || child.r < best.r)) best = child;
    }
  }
  return best;
}

const out = {};
for (const id of learned) {
  const name = names[id];
  if (!name) continue;
  const m = misc[id];
  // Cast at something in range (Blizzard, Flamestrike): not centered on you.
  if (m && ranges[m.RangeIndex] > 0) continue;
  const area = areaOf(id, 0);
  if (!area) continue;
  const prev = out[name];
  if (!prev) out[name] = { r: area.r, kind: area.kind, ids: [id] };
  else { prev.ids.push(id); if (area.r < prev.r) prev.r = area.r; if (area.kind === 'cone') prev.kind = 'cone'; }
}
const list = Object.entries(out).sort((a, b) => a[0].localeCompare(b[0]));
console.log(JSON.stringify(list.map(([n, v]) => [n, v.r, v.kind, v.ids.sort((a, b) => a - b)])));
