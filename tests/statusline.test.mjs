import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const script = fileURLToPath(new URL('../claude/statusline.mjs', import.meta.url));
function render(data) {
  const result = spawnSync(process.execPath, [script], { input: typeof data === 'string' ? data : JSON.stringify(data), encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout;
}
test('native metrics include context cost reasoning quotas tokens and cache', () => {
  const output = render({model:{display_name:'Opus'}, effort:{level:'high'}, thinking:{enabled:true},
    context_window:{used_percentage:25, context_window_size:200000,total_input_tokens:12000,total_output_tokens:3000},
    cost:{total_cost_usd:1.25,total_duration_ms:60000,total_lines_added:5,total_lines_removed:2},
    rate_limits:{five_hour:{used_percentage:0},seven_day:{used_percentage:50}},
    prompt_cache:{warm:true,ttl:'5m',expires_at:Math.floor(Date.now()/1000)+120},version:'2.2.0'});
  for (const part of ['Opus','high','25%','$1.25','12,000','3,000','5h 0%','7d 50%','cache','+5/-2']) assert.ok(output.includes(part), output);
});
test('missing metrics stay unavailable rather than fabricated zero', () => {
  const output = render({});
  assert.ok(output.includes('n/a'));
  assert.ok(!output.includes('$0.00'));
});
test('untrusted labels cannot inject terminal control codes or newlines', () => {
  const output = render({model:{display_name:'bad\u001b[2J\nmodel'},workspace:{current_dir:'/tmp/\u001b]0;evil\u0007'}});
  assert.ok(!output.includes('\u001b'));
  assert.ok(!output.includes('\u0007'));
  assert.ok(output.trimEnd().split('\n').length <= 3);
});
test('malformed JSON does not crash the status command', () => {
  assert.ok(render('{bad').includes('unavailable'));
});
