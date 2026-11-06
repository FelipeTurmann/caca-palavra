import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const revision = '315e063da1f89c89e2097c6e72428ebefb9ab1d1';
const url = 'https://github.com/LuceleneL/PortiLexicon-UD';
const spellingRevision = '4f1df64b2e8e14751aa7c2205d170ca016071315';
const spellingHash = 'a38bfb26b68ece2834e79fe83e48d5792652970ace12db89d1b9674bf9933183';
const tags = ['NOUN', 'ADJ', 'VERB', 'AUX', 'ADV', 'ADP', 'CCONJ', 'SCONJ', 'DET', 'INTJ', 'NUM', 'PRON'];
const norm = s => s.normalize('NFD').replace(/\p{M}/gu, '').toUpperCase();
const sig = s => [...s].sort().join('');

export function prepareCatalogV3(repository, baseline, spellingPath) {
  function readSource(file) {
    return execFileSync('git', ['-C', repository, 'show', `${revision}:${file}`], {
      encoding: 'utf8', maxBuffer: 128 * 1024 * 1024,
    });
  }
  const editorial = [...baseline.words,
    { display: 'ABERTO', clue: 'Que permite a passagem ou a entrada de alguém.', partOfSpeech: 'adjetivo', familiarity: 1 },
    { display: 'PÁTIO', clue: 'Espaço aberto onde alunos podem brincar no recreio.', partOfSpeech: 'substantivo', familiarity: 1 },
  ];
  const targetTags = { substantivo: 'NOUN', adjetivo: 'ADJ', verbo_infinitivo: 'VERB' };
  const reviewed = new Map(editorial.map(word => [word.display, word]));
  const revised = new Set();
  for (const line of fs.readFileSync('tool/content/clues_v3.tsv', 'utf8').split(/\r?\n/)) {
    if (!line.trim() || line.startsWith('#')) continue;
    const [display, clue, extra] = line.split('\t');
    const word = reviewed.get(display);
    if (!word || !clue?.trim() || extra !== undefined || revised.has(display)) {
      throw Error(`Revisão de dica inválida para ${display}.`);
    }
    revised.add(display);
    reviewed.set(display, { ...word, clue, clueVersion: 3 });
  }
  const eligible = new Set();
  const forms = new Map();
  for (const tag of tags) {
    for (const line of readSource(`${tag}.tsv`).split(/\r?\n/)) {
      const [form, lemma, features] = line.split('\t');
      if (!/^[a-záàâãéêíóôõúüç]{3,6}$/.test(form) || !lemma || !features ||
          features.includes('Abbr=Yes') || features.includes('Foreign=Yes')) continue;
      const display = form.toUpperCase();
      const key = norm(form);
      const word = reviewed.get(display);
      if (word && (targetTags[word.partOfSpeech] === tag ||
          (word.partOfSpeech === 'verbo_infinitivo' && tag === 'AUX'))) {
        const allowed = word.partOfSpeech === 'verbo_infinitivo'
          ? form === lemma && features.includes('VerbForm=Inf')
          : !features.includes('Number=Plur');
        if (allowed) eligible.add(display);
      }
      const previous = forms.get(key);
      if (!previous || (!previous.lemmaForm && form === lemma)) {
        forms.set(key, { display, lemmaForm: form === lemma,
          referenceLemma: lemma.toUpperCase(), partOfSpeech: 'outra',
          source: 'portilexicon-ud', familiarity: 3, targetEligible: false });
      }
    }
  }
  const allWords = new Map([...forms].map(([key, { lemmaForm, ...word }]) => [key, word]));
  const spelling = fs.readFileSync(spellingPath);
  if (createHash('sha256').update(spelling).digest('hex') !== spellingHash) {
    throw Error('A revisão do dicionário VERO diverge da revisão usada no catálogo.');
  }
  const spellingWords = new Set(spelling.toString('utf8').split(/\r?\n/)
    .map(line => line.split(/[\/\t ]/, 1)[0].normalize('NFC'))
    .filter(form => /^[a-záàâãéêíóôõúüç]{3,6}$/.test(form)));
  for (const line of fs.readFileSync('tool/content/source/lexico.txt', 'utf8').split(/\r?\n/)) {
    const form = line.normalize('NFC');
    if (!spellingWords.has(form)) continue;
    const key = norm(form);
    if (!allWords.has(key)) {
      const display = form.toUpperCase();
      allWords.set(key, { display, referenceLemma: display, partOfSpeech: 'outra',
        source: 'fserb-vero-reviewed', familiarity: 3, targetEligible: false });
    }
  }
  for (const word of reviewed.values()) {
    allWords.set(norm(word.display), { ...word, targetEligible: eligible.has(word.display),
      source: word.source ?? 'portilexicon-ud', referenceLemma: word.referenceLemma ?? word.display });
  }
  const entries = [...allWords.values()].sort((a, b) => norm(a.display).localeCompare(norm(b.display), 'en'));
  return {
    lexicon: { ...baseline, editorialPolicy: 'pt-br-campaign-explorer-v3',
      scope: 'Respostas de campanha revisadas e formas registradas para o Explorador.',
      sources: [...baseline.sources, { id: 'portilexicon-ud', url, commit: revision,
        license: 'MIT (repositório), CC BY 4.0 (portal de dados)',
        attribution: 'Lucelene Lopes, Magali Sanches Duran, Paulo Fernandes e Thiago Alexandre Salgueiro Pardo (2022). PortiLexicon-UD.',
        use: 'Seleção de formas de 3 a 6 letras, normalização das chaves e classificação para campanha e Explorador.' },
      { id: 'fserb-vero-reviewed', url: 'https://github.com/LibreOffice/dictionaries/tree/master/pt_BR',
        commit: spellingRevision, sha256: spellingHash,
        use: 'Conferência de verbetes do corpus fserb que constam também na grafia minúscula do VERO.' }],
      words: entries },
    license: readSource('LICENSE'),
  };
}

export function writeCatalogV3(directory, prepared, levels, daily) {
  const signatures = new Set();
  for (const level of [...levels, ...daily]) {
    const letters = level.letters;
    for (let mask = 1; mask < 1 << letters.length; mask++) {
      const subset = letters.filter((_, index) => mask & (1 << index));
      if (subset.length >= 3) signatures.add(sig(subset));
    }
  }
  const lexicon = { ...prepared.lexicon,
    words: prepared.lexicon.words.filter(word => signatures.has(sig(norm(word.display)))) };
  fs.writeFileSync(path.join(directory, 'lexicon_pt_br.json'), JSON.stringify(lexicon, null, 2) + '\n');
  fs.writeFileSync(path.join(directory, 'LICENSE-PortiLexicon-UD.txt'), prepared.license);
  return lexicon.words.length;
}
