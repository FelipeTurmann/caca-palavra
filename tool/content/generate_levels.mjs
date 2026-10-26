import fs from 'node:fs';
import { performance } from 'node:perf_hooks';

const started = performance.now();
const norm = s => s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase();
const sig = s => [...s].sort().join('');
const lexicon = JSON.parse(fs.readFileSync('assets/data/lexicon_pt_br.json','utf8'));
const entries = lexicon.words.map(w => ({...w,key:norm(w.display)}));
const bySignature = new Map();
for (const word of entries) {
  const s = sig(word.key);
  if (!bySignature.has(s)) bySignature.set(s,[]);
  bySignature.get(s).push(word);
}
const racks = new Set();
for (const word of entries) {
  if (word.key.length >= 4) racks.add(sig(word.key));
  if (word.key.length >= 3 && word.key.length <= 5) {
    for (const letter of 'AEIORSTNCLMPUDVBGFHZJQX') racks.add(sig(word.key+letter));
  }
}
function formables(rack) {
  const found = new Map();
  const subsets = new Set();
  for (let mask=1;mask<(1<<rack.length);mask++) {
    let s='';
    for(let i=0;i<rack.length;i++) if(mask&(1<<i)) s+=rack[i];
    if(s.length<3 || subsets.has(s)) continue;
    subsets.add(s);
    for (const w of bySignature.get(s)??[]) found.set(w.key,w);
  }
  return [...found.values()].sort((a,b)=>a.key.localeCompare(b.key,'en'));
}
function covers(rack, words) {
  const counts = s => [...s].reduce((m,c)=>(m[c]=(m[c]??0)+1,m),{});
  const have = {};
  for (const w of words) for (const [c,n] of Object.entries(counts(w.key))) have[c]=Math.max(have[c]??0,n);
  return Object.entries(counts(rack)).every(([c,n])=>have[c]>=n);
}
function hash(s) {
  let n=2166136261;
  for(const c of s) n=Math.imul(n^c.charCodeAt(0),16777619)>>>0;
  return n;
}
// Inteiros: fichas, carga de respostas, extensão, familiaridade e anagramas.
function score(rack, words) {
  const anagrams = words.length-new Set(words.map(w=>sig(w.key))).size;
  return 20*(rack.length-4)+8*(words.length-3)
    +words.reduce((n,w)=>n+2*(w.key.length-3)+5*(w.familiarity-1),0)+2*anagrams;
}
const pool = [];
const identities = new Set();
for(const rack of [...racks].sort()) {
  const available=formables(rack);
  if(available.length<4 || Math.max(...available.map(w=>w.key.length))<rack.length-1) continue;
  for(let count=3;count<=Math.min(6,available.length-1);count++) {
    for(let variant=0;variant<6;variant++) {
      const ranked=[...available].sort((a,b)=>hash(`${rack}:${count}:${variant}:${a.key}`)-hash(`${rack}:${count}:${variant}:${b.key}`));
      // Uma resposta longa ajuda a dar sentido ao conjunto de fichas.
      const longest=[...ranked].sort((a,b)=>b.key.length-a.key.length)[0];
      const words=[longest,...ranked.filter(w=>w!==longest)].slice(0,count);
      if(!covers(rack,words)) continue;
      const identity=rack+':'+words.map(w=>w.key).sort().join(',');
      if(identities.has(identity)) continue;
      identities.add(identity);
      const difficultyScore=score(rack,words);
      pool.push({rack,words,identity,score:difficultyScore,
        extraGoal:Math.min(3,available.length-count),extras:available.length-count});
    }
  }
}
const bands=[
  {end:100,name:'introducao',tiles:[4,5],targets:[3,4],rest:[3,3],aim:16},
  {end:500,name:'facil',tiles:[4,5],targets:[3,5],rest:[3,3],aim:33},
  {end:1000,name:'intermediario',tiles:[5,6],targets:[4,5],rest:[3,4],aim:65},
  {end:1750,name:'avancado',tiles:[5,6],targets:[4,6],rest:[3,4],aim:90},
  {end:2500,name:'desafiador',tiles:[6,6],targets:[5,6],rest:[4,5],aim:109},
];
console.log(`Inventário: ${entries.length} palavras, ${racks.size} conjuntos candidatos, ${pool.length} variantes válidas.`);
const used=new Set(), lastRack=new Map(), wordUses=new Map(), levels=[];
function eligible(c,id,band,rest) {
  const tileMin=rest?Math.max(4,band.tiles[0]-1):band.tiles[0];
  const counts=rest?band.rest:band.targets;
  return !used.has(c.identity) && id-(lastRack.get(c.rack)??-1000)>=100
    && c.rack.length>=tileMin && c.rack.length<=band.tiles[1]
    && c.words.length>=counts[0] && c.words.length<=counts[1]
    && c.words.every(w=>w.familiarity<3 && (id>100 || w.familiarity===1))
    && (!rest || c.words.every(w=>w.familiarity===1));
}
function pick(id,band,rest,maxScore=Infinity) {
  let best=null,bestCost=Infinity;
  const aim=rest?Math.max(0,band.aim-32):band.aim;
  const recent = new Set(levels.slice(-5).flatMap(l=>l.words.map(w=>norm(w.display))));
  for(const c of pool) {
    const scoreCost=Math.abs(c.score-aim)*3;
    if(scoreCost>=bestCost) continue;
    if(c.score>=maxScore || !eligible(c,id,band,rest)) continue;
    const load=c.words.reduce((n,w)=>n+(wordUses.get(w.key)??0),0)/c.words.length;
    const proximity=c.words.reduce((n,w)=>n+(recent.has(w.key)?1:0),0);
    const cost=scoreCost+load*0.45+proximity*9+(hash(`${id}:${c.identity}`)%1000)/1000;
    if(cost<bestCost) {best=c;bestCost=cost;}
  }
  if(!best) throw Error(`Sem candidato para nível ${id}, faixa ${band.name}, descanso=${rest}. Regras não foram relaxadas.`);
  return best;
}
function commit(c,id,band,rest) {
  used.add(c.identity);lastRack.set(c.rack,id);
  for(const w of c.words) wordUses.set(w.key,(wordUses.get(w.key)??0)+1);
  const letters=[...c.rack].sort((a,b)=>hash(`${id}:${a}`)-hash(`${id}:${b}`));
  levels.push({id,extraGoal:c.extraGoal,difficulty:band.name,rest,difficultyScore:c.score,
    letters,words:c.words.map(w=>({display:w.display}))});
}
for(let start=1;start<=2500;start+=5) {
  const band=bands.find(b=>start<=b.end);
  // Reservar o nível leve antes, para garantir uma queda real de dificuldade.
  const rest=pick(start+4,band,true);
  for(let offset=0;offset<4;offset++) {
    const id=start+offset;
    let c=id===1 ? pool.find(v=>v.rack==='AGOT' && v.words.map(w=>w.key).sort().join(',')==='ATO,GATO,GOTA') : pick(id,band,false);
    if(!c) throw Error('Nível inicial GATO/GOTA/ATO não encontrado');
    if(c.rack===rest.rack || c.score<=rest.score) {
      const matches=pool.filter(v=>v.rack!==rest.rack && v.score>rest.score && eligible(v,id,band,false));
      if(!matches.length) throw Error(`Sem desafio acima do descanso no bloco ${start}`);
      // Reusar o mesmo seletor com bloqueio temporário da reserva.
      lastRack.set(rest.rack,start+4);
      c=pick(id,band,false);
      lastRack.delete(rest.rack);
      if(c.score<=rest.score) c=matches.sort((a,b)=>Math.abs(a.score-band.aim)-Math.abs(b.score-band.aim))[0];
    }
    commit(c,id,band,false);
  }
  // Nenhum desafio pode consumir o conjunto reservado para a posição de descanso.
  if(!eligible(rest,start+4,band,true)) throw Error(`Reserva de descanso inválida em ${start+4}`);
  commit(rest,start+4,band,true);
}
// Sete definições diárias revistas, mantendo a rotação e a data-base anteriores.
const oldDaily=JSON.parse(fs.readFileSync('assets/data/daily_levels.json','utf8'));
const daily=levels.slice(0,7).map(l=>({...l,words:l.words.map(w=>({...w}))}));
const policy={expectedLevelCount:2500,minimumRackDistance:100,restEvery:5,
  scoreVersion:1,scoreFormula:'20*(tiles-4)+8*(answers-3)+sum(2*(length-3)+5*(familiarity-1))+2*anagramOverlap',bands};
fs.writeFileSync('assets/data/levels.json',JSON.stringify({schemaVersion:1,catalogVersion:2,language:'pt-BR',minimumWordLength:3,policy,levels},null,2)+'\n');
fs.writeFileSync('assets/data/daily_levels.json',JSON.stringify({schemaVersion:1,catalogVersion:2,baseDate:oldDaily.baseDate,levels:daily},null,2)+'\n');
const report={lexiconEntries:entries.length,candidateRacks:racks.size,candidateVariants:pool.length,levels:levels.length,
  distinctRacks:new Set(levels.map(l=>sig(l.letters.join('')))).size,
  distinctTargets:wordUses.size,restLevels:levels.filter(l=>l.rest).length,
  bands:bands.map((b,i)=>{const from=i?bands[i-1].end+1:1,ls=levels.filter(l=>l.id>=from&&l.id<=b.end);return{from,to:b.end,name:b.name,levels:ls.length,meanScore:ls.reduce((n,l)=>n+l.difficultyScore,0)/ls.length}}),
  mostFrequentTargets:[...wordUses].sort((a,b)=>b[1]-a[1]).slice(0,20),
  unusedWords:entries.filter(w=>!wordUses.has(w.key)).map(w=>w.display)};
fs.writeFileSync('tool/content/generation_report.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({...report,mostFrequentTargets:undefined,unusedWords:undefined,seconds:(performance.now()-started)/1000},null,2));
