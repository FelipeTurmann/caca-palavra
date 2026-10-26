import fs from 'node:fs';
import crypto from 'node:crypto';

export const normalize = s => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toUpperCase();
export const signature = s => [...normalize(s)].sort().join('');
const sourcePath = 'tool/content/source/lexico.txt';
const reference = new Set(fs.readFileSync(sourcePath, 'utf8').trim().split(/\r?\n/).map(s => s.normalize('NFC').toUpperCase()));
const legacy = JSON.parse(fs.readFileSync('test/fixtures/lexicon_v1.json', 'utf8'));
const removed = new Set(['ARDE', 'COA', 'OPTA', 'PARE', 'TOPA']);
const classes = { n: 'substantivo', a: 'adjetivo', v: 'verbo_infinitivo', o: 'outra' };
const words = new Map();
const legacyAdjectives = new Set(['APTO', 'BOA', 'CAROS', 'OCO', 'RASO']);
const rejected = [];
// Somente entradas explícitas do TSV são admitidas. Estas regras conferem a
// relação com o lema de referência; não criam plurais ou femininos no jogo.
const irregularBases = { 'ANÉIS':'ANEL', 'PÃES':'PÃO', 'GRÃOS':'GRÃO', 'MÃOS':'MÃO', 'AUTORA':'AUTOR' };
function referenceLemma(display) {
  const candidates = [display, irregularBases[display], display.replace(/S$/,''),
    display.replace(/ES$/,''), display.replace(/A$/,'O'),
    display.replace(/AS$/,'O'), display.replace(/ES$/,'E')];
  return candidates.find(s => s && reference.has(s));
}
for (const word of legacy.words) {
  if (removed.has(normalize(word.display))) {
    rejected.push({display: word.display, reason: 'conjugação verbal sem significado independente selecionado'});
    continue;
  }
  const partOfSpeech = ['COAR','DAR'].includes(word.display) ? 'verbo_infinitivo'
    : ['OBA','OLÁ'].includes(word.display) ? 'outra'
    : legacyAdjectives.has(word.display) ? 'adjetivo' : 'substantivo';
  words.set(normalize(word.display), {...word, partOfSpeech, familiarity: 1, source: 'prototype-reviewed'});
}
for (const [i,line] of fs.readFileSync('tool/content/vocabulary.tsv','utf8').split(/\r?\n/).entries()) {
  if (!line.trim() || line.startsWith('#')) continue;
  const fields = line.split('|');
  if (fields.length !== 4) throw Error(`Linha ${i+1}: quatro campos esperados`);
  const [display, code, familiarityText, clue] = fields;
  const key = normalize(display);
  const familiarity = Number(familiarityText);
  if (!classes[code] || ![1,2,3].includes(familiarity) || !clue.trim()) throw Error(`Linha ${i+1}: metadados inválidos`);
  if (familiarity === 3) {
    rejected.push({display, reason: 'termo pouco familiar para a política de vocabulário comum'});
    continue;
  }
  if (key.length < 3 || key.length > 6) {
    rejected.push({display, reason: 'comprimento fora de 3–6 letras'});
    continue;
  }
  const lemma = referenceLemma(display);
  if (!/^[A-Z]+$/.test(key) || !lemma) throw Error(`Grafia não confirmada na referência: ${display}`);
  if (clue.length > 120 || new RegExp(`(^|[^A-Z])${key}([^A-Z]|$)`).test(normalize(clue))) throw Error(`Frase inválida: ${display}`);
  const previous = words.get(key);
  if (previous && previous.display !== display) throw Error(`Colisão editorial: ${previous.display} / ${display}`);
  words.set(key, {display, clue, partOfSpeech: classes[code], familiarity, source: 'fserb-reviewed', referenceLemma: lemma});
}
const entries = [...words.values()].sort((a,b) => normalize(a.display).localeCompare(normalize(b.display), 'en'));
for (const word of entries) {
  word.referenceLemma ??= referenceLemma(word.display);
  if (!word.referenceLemma) throw Error(`Legado sem confirmação: ${word.display}`);
  if (removed.has(normalize(word.display))) throw Error(`Conjugação excluída: ${word.display}`);
}
const sources = [{id:'fserb-reviewed', url:'https://github.com/fserb/pt-br',
  commit: fs.readFileSync('tool/content/source/fserb-commit.txt','utf8').trim().replace(/^\uFEFF/,''),
  license:'MIT', sha256:crypto.createHash('sha256').update(fs.readFileSync(sourcePath)).digest('hex'),
  use:'Conferência de grafia; seleção e frases próprias do projeto.'},
  {id:'prototype-reviewed', use:'Vocabulário original do projeto revisto pela política nova e conferido na mesma referência.'}];
fs.writeFileSync('assets/data/lexicon_pt_br.json', JSON.stringify({schemaVersion:1,language:'pt-BR',
  scope:'Vocabulário editorial para campanha e diário; não é um dicionário completo.',clueVersion:2,
  editorialPolicy:'common-pt-br-infinitives-v1',sources,words:entries},null,2)+'\n');
fs.writeFileSync('tool/content/rejected.json', JSON.stringify(rejected,null,2)+'\n');
fs.copyFileSync('tool/content/source/LICENSE-fserb.txt','assets/data/LICENSE-fserb.txt');
console.log(`${entries.length} palavras preparadas; ${rejected.length} entradas excluídas.`);
