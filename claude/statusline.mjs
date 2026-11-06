#!/usr/bin/env node
// Native Claude statusLine protocol: stdin JSON -> text. No network or credentials.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
const clean = value => String(value ?? '').replace(/[\u0000-\u001f\u007f-\u009f]/g, '').slice(0, 160);
const number = value => typeof value === 'number' && Number.isFinite(value);
const count = value => number(value) ? value.toLocaleString('en-US') : 'n/a';
const pct = value => number(value) ? `${Math.round(value)}%` : 'n/a';
const money = value => number(value) ? `$${value.toFixed(2)}` : 'n/a';
const seconds = value => `${Math.floor(value / 60)}m${Math.floor(value % 60).toString().padStart(2, '0')}s`;

try {
  const d = JSON.parse(fs.readFileSync(0, 'utf8'));
  if (!d || typeof d !== 'object' || Array.isArray(d)) throw new Error('Invalid status');
  const c = d.context_window ?? {}, cost = d.cost ?? {}, rate = d.rate_limits ?? {};
  const cwd = d.workspace?.current_dir ?? d.cwd;
  const first = [clean(d.model?.display_name ?? d.model?.id ?? 'model n/a')];
  if (d.effort?.level != null) first.push(`reasoning ${clean(d.effort.level)}`);
  if (typeof d.thinking?.enabled === 'boolean') first.push(`thinking ${d.thinking.enabled ? 'on' : 'off'}`);
  if (typeof cwd === 'string') {
    first.push(clean(path.basename(cwd)));
    try {
      const branch = execFileSync('git', ['-C', cwd, 'branch', '--show-current'], { encoding: 'utf8', timeout: 300, stdio: ['ignore','pipe','ignore'], env: { ...process.env, GIT_OPTIONAL_LOCKS: '0' } }).trim();
      if (branch) first.push(clean(branch));
    } catch { /* Not a git workspace or git unavailable. */ }
  }
  if (d.version) first.push(`v${clean(d.version)}`);
  const metrics = [`ctx ${pct(c.used_percentage)} / ${count(c.context_window_size)}`, `cost ${money(cost.total_cost_usd)}`,
    `in ${count(c.total_input_tokens)}`, `out ${count(c.total_output_tokens)}`];
  for (const [key, label] of [['five_hour','5h'], ['seven_day','7d']]) {
    const limit = rate[key];
    if (number(limit?.used_percentage)) {
      let text = `${label} ${pct(limit.used_percentage)} used`;
      if (number(limit.resets_at)) text += ` reset ${seconds(Math.max(0, limit.resets_at - Date.now()/1000))}`;
      metrics.push(text);
    }
  }
  const spend = rate.spend_limit;
  if (spend) metrics.push(number(spend.used_usd) && number(spend.limit_usd)
    ? `spend ${money(spend.used_usd)}/${money(spend.limit_usd)}` : `spend ${pct(spend.used_percentage)}`);
  const cache = d.prompt_cache;
  if (cache) {
    const remaining = number(cache.expires_at) ? Math.max(0, cache.expires_at - Date.now()/1000) : null;
    metrics.push(`cache ${cache.warm ? 'warm' : 'cold'}${remaining !== null && cache.warm ? ` ${seconds(remaining)}` : ''}`);
  }
  if (number(cost.total_duration_ms)) metrics.push(seconds(cost.total_duration_ms/1000));
  if (number(cost.total_lines_added) && number(cost.total_lines_removed)) metrics.push(`+${cost.total_lines_added}/-${cost.total_lines_removed}`);
  console.log(first.join(' | '));
  console.log(metrics.join(' | '));
} catch {
  console.log('status unavailable');
}
