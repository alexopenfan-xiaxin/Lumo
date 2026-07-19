import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const source = await readFile(new URL('_worker.js', import.meta.url), 'utf8');
const contract = JSON.parse(await readFile(new URL('openapi.json', import.meta.url), 'utf8'));
const {parseAgentDraft, quotaPolicy, validAgent, validImageUpload, validInviteCount, publicAgent} = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

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
assert.equal(validImageUpload({type: 'image/webp', size: 1_000_000}), true);
assert.equal(validImageUpload({type: 'image/gif', size: 100}), false);
assert.equal(validImageUpload({type: 'image/png', size: 1_000_001}), false);
assert.equal(contract.openapi, '3.1.0');
assert.ok(contract.paths['/admin/agents/{id}'].put);
assert.ok(contract.paths['/admin/agents/draft'].post);
assert.equal(contract.components.schemas.AgentInput.properties.color.pattern, '^#[0-9A-Fa-f]{6}$');
assert.equal(parseAgentDraft(JSON.stringify(agent), 8).sortOrder, 8);
assert.equal(parseAgentDraft('{"name":"少字段"}', 0), null);
