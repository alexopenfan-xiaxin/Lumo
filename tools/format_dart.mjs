import {format} from '@wasm-fmt/dart_fmt';
import {readdir, readFile, writeFile} from 'node:fs/promises';
import {join} from 'node:path';

const dartFiles = async (directory) => {
  const entries = await readdir(directory, {withFileTypes: true});
  return (await Promise.all(entries.map((entry) =>
    entry.isDirectory() ? dartFiles(join(directory, entry.name)) : entry.name.endsWith('.dart') ? [join(directory, entry.name)] : [],
  ))).flat();
};

const files = (await Promise.all(['lib', 'test'].map(dartFiles))).flat();
let changed = 0;
for (const file of files) {
  const source = await readFile(file, 'utf8');
  const lineEnding = source.includes('\r\n') ? '\r\n' : '\n';
  const formatted = format(source).replaceAll('\n', lineEnding);
  if (formatted === source) continue;
  await writeFile(file, formatted);
  changed += 1;
}
console.log(`Formatted ${files.length} files (${changed} changed).`);
