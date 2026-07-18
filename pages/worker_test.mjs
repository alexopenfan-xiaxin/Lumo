import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const source = await readFile(new URL('_worker.js', import.meta.url), 'utf8');
const {quotaPolicy, validInviteCount} = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

assert.deepEqual(quotaPolicy(null), {limit: 10, period: 'lifetime'});
assert.deepEqual(quotaPolicy({is_member: 0}), {limit: 100, period: 'daily'});
assert.equal(quotaPolicy({is_member: 1}), null);
assert.equal(validInviteCount(1), true);
assert.equal(validInviteCount(100), true);
assert.equal(validInviteCount(0), false);
assert.equal(validInviteCount(101), false);
