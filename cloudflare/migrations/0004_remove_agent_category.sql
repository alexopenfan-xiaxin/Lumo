ALTER TABLE agents DROP COLUMN category;

UPDATE agents
SET system_prompt = rtrim(substr(system_prompt, 1, instr(system_prompt, char(10) || '# 安全与边界') - 1))
WHERE instr(system_prompt, char(10) || '# 安全与边界') > 0;

UPDATE agents
SET system_prompt = rtrim(substr(system_prompt, 1, instr(system_prompt, char(10) || '# 安全边界') - 1))
WHERE instr(system_prompt, char(10) || '# 安全边界') > 0;

UPDATE agents
SET system_prompt = rtrim(substr(system_prompt, 1, instr(system_prompt, char(10) || '安全边界：') - 1))
WHERE instr(system_prompt, char(10) || '安全边界：') > 0;
