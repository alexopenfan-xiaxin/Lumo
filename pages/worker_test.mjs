import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const source = await readFile(new URL('_worker.js', import.meta.url), 'utf8');
const {quotaPolicy} = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

assert.deepEqual(quotaPolicy(null), {limit: 10, period: 'lifetime'});
assert.deepEqual(quotaPolicy({is_member: 0}), {limit: 100, period: 'daily'});
assert.equal(quotaPolicy({is_member: 1}), null);
