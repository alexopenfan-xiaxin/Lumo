import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';

const source = await readFile(new URL('_worker.js', import.meta.url), 'utf8');
const contract = JSON.parse(await readFile(new URL('openapi.json', import.meta.url), 'utf8'));
const {buildEpaySign, chatMessages, completionOptions, computeMemberExpiry, explicitlyRequestsImage, imageGenerationTool, parseAccountId, parseAgentDraft, parseImagePlan, quotaPolicy, searchResults, updateAccount, validAgent, validImageSize, validImageUpload, validInviteCount, validMessages, webSearchTool, publicAgent} = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

// Reference MD5 oracle: node's crypto. Used to assert our pure-JS impl matches.
const md5Hex = (str) => createHash('md5').update(str, 'utf8').digest('hex');

// ponytail: in-memory KV stub for quotaPolicy/createOrder/notify tests.
// Ceiling: only supports get/put/delete/list on a flat Map; no real TTL eviction.
const kvJsonStub = (entries = {}) => {
  const map = new Map();
  for (const [k, v] of Object.entries(entries)) map.set(k, JSON.stringify(v));
  return {
    get: async (key, type) => {
      if (!map.has(key)) return null;
      const v = map.get(key);
      return type === 'json' ? JSON.parse(v) : v;
    },
    put: async (key, val) => void map.set(key, val),
    delete: async (key) => void map.delete(key),
    list: async ({prefix} = {}) => ({keys: [...map.keys()].filter((k) => k.startsWith(prefix ?? '')).map((name) => ({name}))}),
  };
};
const envNoKV = {};
const envEmptyKV = {KV: kvJsonStub()};
const now = Date.now();
const dayMs = 86_400_000;

// 游客
assert.deepEqual(await quotaPolicy(envEmptyKV, null), {limit: 10, period: 'lifetime'});
// 注册用户（无 KV 记录）
assert.deepEqual(await quotaPolicy(envEmptyKV, {id: 'a1', is_member: 0}), {limit: 50, period: 'daily'});
// 永久会员
assert.equal(await quotaPolicy(envEmptyKV, {id: 'a1', is_member: 1}), null);
// 月度会员（KV 有效）
const envMonthly = {KV: kvJsonStub({'member:a1': {plan: 'monthly', expire_at: now + dayMs, updated_at: now}})};
assert.deepEqual(await quotaPolicy(envMonthly, {id: 'a1', is_member: 0}), {limit: 200, period: 'daily', contextLimit: 256000});
// 月度会员过期 → 回退为注册用户
const envExpired = {KV: kvJsonStub({'member:a1': {plan: 'monthly', expire_at: now - 1000, updated_at: now}})};
assert.deepEqual(await quotaPolicy(envExpired, {id: 'a1', is_member: 0}), {limit: 50, period: 'daily'});
// KV 缺失/不可用 → 注册用户降级（不抛错）
assert.deepEqual(await quotaPolicy(envNoKV, {id: 'a1', is_member: 0}), {limit: 50, period: 'daily'});

// MD5 sign 测试：用 node crypto 作为对照 oracle
assert.equal(buildEpaySign({}, 'key'), md5Hex('key')); // 空参 → md5(key)
assert.equal(buildEpaySign({a: '1', b: '2'}, ''), md5Hex('a=1&b=2'));
assert.equal(buildEpaySign({b: '2', a: '1', sign: 'xxx', sign_type: 'MD5'}, 'k'), md5Hex('a=1&b=2k'));
assert.equal(buildEpaySign({a: '', b: null, c: '3'}, 'k'), md5Hex('c=3k')); // 空值参数被过滤
// 已知 RFC 1321 向量：md5('') = d41d8cd98f00b204e9800998ecf8427e
assert.equal(md5Hex(''), 'd41d8cd98f00b204e9800998ecf8427e');

// parseAccountId
assert.equal(parseAccountId('LUMO_abc123_deadbeef'), 'abc123');
assert.equal(parseAccountId('LUMO_a-b_c_001_ff'), 'a-b_c_001');
assert.equal(parseAccountId('not_lumo'), null);
assert.equal(parseAccountId(null), null);
assert.equal(parseAccountId(42), null);

// computeMemberExpiry
assert.equal(computeMemberExpiry(null, now, 30 * dayMs), now + 30 * dayMs);
assert.equal(computeMemberExpiry(now - 1000, now, 30 * dayMs), now + 30 * dayMs); // 已过期 → 从 now 起
assert.equal(computeMemberExpiry(now + dayMs, now, 30 * dayMs), now + dayMs + 30 * dayMs); // 有效期累加

assert.equal(validInviteCount(1), true);
assert.equal(validInviteCount(100), true);
assert.equal(validInviteCount(0), false);
assert.equal(validInviteCount(101), false);
assert.equal(validMessages([{role: 'user', content: '你好'}]), true);
assert.equal(validMessages([null]), false);
assert.equal(validMessages([42]), false);

// OpenAPI 同步：新增端点必须出现在契约里
assert.ok(contract.paths['/create-order'].post, 'openapi: missing POST /create-order');
assert.ok(contract.paths['/notify'].post, 'openapi: missing POST /notify');
assert.ok(contract.paths['/membership'].get, 'openapi: missing GET /membership');
assert.ok(contract.paths['/admin/orders'].get, 'openapi: missing GET /admin/orders');
assert.ok(contract.paths['/admin/orders/{trade_no}'].get, 'openapi: missing GET /admin/orders/{trade_no}');
assert.equal(contract.components.schemas.Membership.required.includes('isMember'), true);

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
