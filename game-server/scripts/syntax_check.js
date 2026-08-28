'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.join(__dirname, '..');
const ignored = new Set(['node_modules', 'coverage', '.git']);
const files = [];

function visit(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ignored.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) visit(full);
    else if (entry.isFile() && entry.name.endsWith('.js')) files.push(full);
  }
}

visit(root);
let failures = 0;
for (const file of files) {
  const result = spawnSync(process.execPath, ['--check', file], { encoding: 'utf8' });
  if (result.status !== 0) {
    failures++;
    process.stderr.write(`${path.relative(root, file)}\n${result.stderr}`);
  }
}

if (failures > 0) process.exitCode = 1;
else console.log(`Syntax check passed: ${files.length} JavaScript files`);
