import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const source = await readFile(new URL('_worker.js', import.meta.url), 'utf8');
const contract = JSON.parse(await readFile(new URL('openapi.json', import.meta.url), 'utf8'));
const {chatMessages, completionOptions, explicitlyRequestsImage, imageGenerationTool, parseAgentDraft, parseImagePlan, quotaPolicy, searchResults, updateAccount, validAgent, validImageSize, validImageUpload, validInviteCount, webSearchTool, publicAgent} = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

assert.deepEqual(quotaPolicy(null), {limit: 10, period: 'lifetime'});
assert.deepEqual(quotaPolicy({is_member: 0}), {limit: 100, period: 'daily'});
assert.equal(quotaPolicy({is_member: 1}), null);
assert.equal(validInviteCount(1), true);
assert.equal(validInviteCount(100), true);
assert.equal(validInviteCount(0), false);
assert.equal(validInviteCount(101), false);

const agent = {
  id: 'new_agent', name: '新伙伴', glyph: '新', tagline: '一句介绍', color: '#A45F41',
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
assert.deepEqual(completionOptions('deepseek-v4-flash', [], 480), {
  model: 'deepseek-v4-flash', messages: [], max_tokens: 480, stream: false,
  thinking: {type: 'enabled'}, reasoning_effort: 'low',
});
assert.deepEqual(completionOptions('sensenova-6.7-flash-lite', [], 480), {
  model: 'sensenova-6.7-flash-lite', messages: [], max_tokens: 480, stream: false,
  temperature: 0.82, top_p: 0.9,
});
assert.equal(completionOptions('deepseek-v4-flash', [], 480, [webSearchTool]).tool_choice, 'auto');
assert.equal(imageGenerationTool.function.name, 'generate_image');
assert.equal(validImageSize('2048x2048'), true);
assert.equal(validImageSize('1024x1024'), false);
assert.equal(explicitlyRequestsImage([{role: 'user', content: '请画一张猫咪插画'}]), true);
assert.equal(explicitlyRequestsImage([{role: 'user', content: '我想要一张你的照片'}]), true);
assert.equal(explicitlyRequestsImage([{role: 'user', content: '给我做个夏日头像吧'}]), true);
assert.equal(explicitlyRequestsImage([{role: 'user', content: '照片为什么会褪色？'}]), false);
assert.equal(explicitlyRequestsImage([{role: 'user', content: '今天有点累'}]), false);
assert.deepEqual(parseImagePlan('{"generate":false}'), {generate: false});
assert.equal(parseImagePlan('{"generate":true,"prompt":"猫","size":"2048x2048","status":"正在画猫"}').generate, true);
assert.equal(completionOptions('deepseek-v4-flash', [], 480, [], true).stream, true);
assert.deepEqual(searchResults([{title: 'Result', url: 'https://example.com', highlights: ['A', 1]}]), [{title: 'Result', url: 'https://example.com', highlights: 'A'}]);
assert.equal(contract.openapi, '3.1.0');
assert.ok(contract.paths['/admin/agents/{id}'].put);
assert.ok(contract.paths['/admin/agents/draft'].post);
assert.equal(contract.components.schemas.AgentInput.properties.color.pattern, '^#[0-9A-Fa-f]{6}$');
assert.equal('category' in contract.components.schemas.AgentInput.properties, false);
const prompts = chatMessages('专属身份', [{role: 'user', content: '你好'}]);
assert.match(prompts[0].content, /Lumo 全局规则/);
assert.equal(prompts[1].content, '专属身份');
assert.deepEqual(prompts[2], {role: 'user', content: '你好'});
assert.equal(parseAgentDraft(JSON.stringify(agent), 8).sortOrder, 8);
assert.equal(parseAgentDraft('{"name":"少字段"}', 0), null);

const testPasswordHash = async (password, salt) => {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', encoder.encode(password), 'PBKDF2', false, ['deriveBits']);
  return Buffer.from(await crypto.subtle.deriveBits({name: 'PBKDF2', hash: 'SHA-256', salt: encoder.encode(salt), iterations: 100000}, key, 256)).toString('hex');
};
const account = {
  id: 'account-1', username: 'old_name', password_salt: 'salt',
  password_hash: await testPasswordHash('old-password', 'salt'), is_member: 0, role: 'user',
};
const accountEnv = (existingUsername = null) => {
  const batches = [];
  const runs = [];
  const DB = {
    prepare(sql) {
      return {
        bind(...args) {
          return {
            first: async () => sql === 'SELECT * FROM accounts WHERE id = ?' ? account : existingUsername,
            run: async () => runs.push({sql, args}),
            sql, args,
          };
        },
      };
    },
    batch: async (statements) => batches.push(statements),
  };
  return {DB, batches, runs};
};
const patchRequest = (body) => new Request('https://lumo.test/auth/account', {
  method: 'PATCH', headers: {'content-type': 'application/json'}, body: JSON.stringify(body),
});

let response = await updateAccount(patchRequest({currentPassword: 'old-password', username: 'new_name'}), accountEnv(), null);
assert.equal(response.status, 401);
response = await updateAccount(patchRequest({currentPassword: 'wrong-password', username: 'new_name'}), accountEnv(), account);
assert.equal(response.status, 401);
response = await updateAccount(patchRequest({currentPassword: 'old-password'}), accountEnv(), account);
assert.equal(response.status, 400);
response = await updateAccount(patchRequest({currentPassword: 'old-password', newPassword: 'short'}), accountEnv(), account);
assert.equal(response.status, 400);
response = await updateAccount(patchRequest({currentPassword: 'old-password', username: 'new_name'}), accountEnv({id: 'other'}), account);
assert.equal(response.status, 409);
const renamed = accountEnv();
response = await updateAccount(patchRequest({currentPassword: 'old-password', username: 'New_Name'}), renamed, account);
assert.equal(response.status, 200);
assert.equal((await response.json()).username, 'new_name');
assert.match(renamed.batches[0][1].sql, /DELETE FROM sessions/);
assert.match(renamed.runs[0].sql, /INSERT INTO sessions/);
const passwordChanged = accountEnv();
response = await updateAccount(patchRequest({currentPassword: 'old-password', newPassword: 'new-password'}), passwordChanged, account);
assert.equal(response.status, 200);
assert.notEqual(passwordChanged.batches[0][0].args[1], account.password_hash);
assert.ok(contract.paths['/auth/account'].patch);
assert.deepEqual(contract.components.schemas.AccountUpdate.required, ['currentPassword']);
