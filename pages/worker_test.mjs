import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const source = await readFile(new URL('_worker.js', import.meta.url), 'utf8');
const {quotaPolicy, validAgent, validInviteCount, publicAgent} = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

assert.deepEqual(quotaPolicy(null), {limit: 10, period: 'lifetime'});
assert.deepEqual(quotaPolicy({is_member: 0}), {limit: 100, period: 'daily'});
assert.equal(quotaPolicy({is_member: 1}), null);
assert.equal(validInviteCount(1), true);
assert.equal(validInviteCount(100), true);
assert.equal(validInviteCount(0), false);
assert.equal(validInviteCount(101), false);

const agent = {
  id: 'new_agent', name: '新伙伴', glyph: '新', tagline: '一句介绍', category: 'listener', color: '#A45F41',
  people: '陪伴者', lastMessage: '最近消息', openingMessage: '你好', avatarUrl: '', systemPrompt: '完整的身份与安全边界', enabled: true, sortOrder: 5,
};
assert.equal(validAgent(agent), true);
assert.equal(validAgent({...agent, id: '../bad'}), false);
assert.equal(validAgent({...agent, avatarUrl: 'http://unsafe.example/avatar.jpg'}), false);
assert.equal(validAgent({...agent, color: 'purple'}), false);
assert.equal(publicAgent({...agent, id: 'meow', avatarUrl: 'https://lumo-ai-bod.pages.dev/avatars/meow.jpg'}).avatarUrl, '');
assert.equal(publicAgent({...agent, id: 'meow', avatarUrl: 'https://example.com/new.jpg'}).avatarUrl, 'https://example.com/new.jpg');
