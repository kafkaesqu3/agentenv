// Local inspection only. Does not load profiles, credentials or agent sessions.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';

const args = process.argv.slice(2);
let json = false, manifest, agents = ['claude', 'codex', 'opencode'];
function usage() { console.log('doctor [--json] [--agents claude,codex,opencode|none] [--manifest FILE|auto]'); }
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--json') json = true;
  else if (args[i] === '--manifest' && args[i + 1] && !args[i + 1].startsWith('--')) manifest = args[++i];
  else if (args[i] === '--agents' && args[i + 1]) {
    const value = args[++i]; agents = value === 'none' ? [] : [...new Set(value.split(','))];
    if (agents.some(a => !['claude','codex','opencode'].includes(a))) { usage(); process.exit(2); }
  } else if (['--help','-h'].includes(args[i])) { usage(); process.exit(0); }
  else { usage(); process.exit(2); }
}
const win = process.platform === 'win32';
const env = process.env, home = os.homedir();
const state = env.AGENTENV_STATE_DIR || path.join(home, '.local', 'state', 'agentenv');
const dirs = {
  claude: env.CLAUDE_CONFIG_DIR || path.join(home,'.claude'),
  codex: env.CODEX_HOME || path.join(home,'.codex'),
  opencode: env.OPENCODE_CONFIG_DIR || path.join(env.XDG_CONFIG_HOME || path.join(home,'.config'),'opencode')
};
function candidates(name) {
  const results = [];
  for (const dir of (env.PATH || '').split(path.delimiter).filter(Boolean)) {
    for (const ext of win ? ['.exe','.cmd','.bat',''] : ['']) {
      const file = path.resolve(dir, name + ext);
      try {
        fs.accessSync(file, fs.constants.X_OK);
        if (fs.statSync(file).isFile() && !results.includes(file)) results.push(file);
      } catch { /* Missing or inaccessible entry. */ }
    }
  }
  return results;
}
function probe(name, aliases = [name], argv = ['--version']) {
  const paths = aliases.flatMap(candidates);
  let result;
  if (paths[0]) {
    // cmd shims (npm and npm-installed CLIs) need cmd.exe on Windows.
    const cmd = win && /\.(cmd|bat)$/i.test(paths[0]);
    if (cmd && /["%\r\n]/.test(paths[0])) result = {status:1, stderr:'Unsupported characters in executable path'};
    else result = spawnSync(cmd ? (env.ComSpec || 'cmd.exe') : paths[0],
      cmd ? ['/d','/s','/c',`""${paths[0]}" ${argv.join(' ')}"`] : argv,
      {encoding:'utf8', timeout:5000, maxBuffer:65536, windowsHide:true, windowsVerbatimArguments:cmd});
  }
  const version = (result?.stdout || result?.stderr || '').trim().split(/\r?\n/)[0]?.slice(0,300) || null;
  let ok = result?.status === 0;
  if (name === 'node') ok &&= /^v(\d+)/.test(version || '') && Number(RegExp.$1) >= 22;
  if (name === 'python') ok &&= /^Python 3\./.test(version || '');
  return {name, ok:!!ok, path:paths[0] || null, version, alternatives:paths.slice(1), error:result?.error?.code || null};
}
function writable(directory) {
  let ancestor = path.resolve(directory);
  try {
    while (!fs.existsSync(ancestor)) {
      const parent = path.dirname(ancestor); if (parent === ancestor) throw new Error('No existing ancestor'); ancestor = parent;
    }
    if (!fs.statSync(ancestor).isDirectory()) throw new Error('Not a directory');
    fs.accessSync(ancestor, fs.constants.W_OK | fs.constants.X_OK);
    return {path:path.resolve(directory), checkedAncestor:ancestor, ok:true};
  } catch (error) { return {path:path.resolve(directory), ok:false, error:error.code || error.message}; }
}
const tools = ['git','curl','rg','jq','node','npm','uv','tar'].map(n=>probe(n));
tools.push(probe('fd',['fd','fdfind']),probe('python',win ? ['python','python3'] : ['python3']));
if (win) tools.push(probe('powershell',['pwsh','powershell'],['-NoProfile','-Command','$PSVersionTable.PSVersion.ToString()']),probe('7zip',['7z'],[]));
else tools.push(probe('bash'),probe('gzip'),probe('unzip',['unzip'],['-v']));
tools.push(...agents.map(a=>probe(a)));
const configs = agents.map(agent => {
  const file = agent === 'opencode' ? (env.OPENCODE_CONFIG || path.join(dirs[agent],'opencode.json')) : path.join(dirs[agent],agent==='claude'?'settings.json':'config.toml');
  try { fs.accessSync(file,fs.constants.R_OK); return {agent,path:file,ok:fs.statSync(file).isFile()}; }
  catch { return {agent,path:file,ok:false}; }
});
const directories = [os.tmpdir(),state,...agents.map(a=>dirs[a]),...agents.map(a=>a==='codex'?path.join(dirs[a],'log'):a==='claude'?path.join(dirs[a],'projects'):path.join(env.XDG_DATA_HOME || path.join(home,'.local','share'),'opencode','log'))].map(writable);
const warnings = tools.filter(t=>t.alternatives.length).map(t=>`${t.name}: multiple PATH candidates; first is active`);
const report = {schemaVersion:1,generatedAt:new Date().toISOString(),platform:process.platform,architecture:process.arch,
  healthy:[...tools,...configs,...directories].every(c=>c.ok), tools,configs,directories,warnings};
if (manifest) {
  const file = manifest === 'auto' ? path.join(state,'manifests',`${Date.now()}-${randomUUID()}.json`) : path.resolve(manifest);
  try {
    fs.mkdirSync(path.dirname(file),{recursive:true});
    // Exclusive creation refuses existing files and dangling symlinks; never overwrite a previous build record.
    fs.writeFileSync(file,JSON.stringify(report,null,2)+'\n',{flag:'wx',mode:0o600});
    console.log(`Manifest: ${file}`);
    if (!report.healthy) console.error('Manifest recorded an incomplete environment; run doctor for details.');
  } catch(error) { console.error(error.message); process.exit(1); }
} else {
  if (json) console.log(JSON.stringify(report,null,2));
  else {
    for (const t of tools) console.log(`${t.ok?'OK':'FAIL'} ${t.name}: ${t.version || 'missing/unusable'} (${t.path || 'not on PATH'})`);
    for (const c of configs) console.log(`${c.ok?'OK':'FAIL'} ${c.agent} config: ${c.path}`);
    for (const d of directories) console.log(`${d.ok?'OK':'FAIL'} writable: ${d.path}`);
    for (const warning of warnings) console.log(`WARN ${warning}`);
  }
  process.exitCode = report.healthy ? 0 : 1;
}
