import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
const script = new URL('../lib/doctor.mjs', import.meta.url);
function run(args, env) { return spawnSync(process.execPath, [script.pathname, ...args], {encoding:'utf8', env:{...process.env, ...env}}); }
test('missing tools are explicit JSON failures without creating files', () => {
 const dir=fs.mkdtempSync(path.join(process.cwd(),'.test-doctor-'));
 try {
  const r=run(['--json','--agents','none'],{HOME:dir,PATH:dir});
  assert.equal(r.status,1); const report=JSON.parse(r.stdout);
  assert.ok(report.tools.some(t=>t.name==='git' && !t.ok));
  assert.deepEqual(fs.readdirSync(dir),[]);
 } finally {fs.rmSync(dir,{recursive:true});}
});
test('manifest records incomplete state and refuses an existing target',()=>{
 const dir=fs.mkdtempSync(path.join(process.cwd(),'.test-manifest-'));
 try {
  const file=path.join(dir,'manifest.json');
  const r=run(['--manifest',file,'--agents','none'],{HOME:dir,PATH:dir});
  assert.equal(r.status,0,r.stderr); assert.equal(JSON.parse(fs.readFileSync(file)).healthy,false);
  assert.notEqual(run(['--manifest',file],{HOME:dir}).status,0);
 } finally {fs.rmSync(dir,{recursive:true});}
});
test('unknown args fail before manifest writes',()=>{
 const r=run(['--manifest','unwanted.json','--bad'],{});assert.equal(r.status,2);
 assert.equal(fs.existsSync('unwanted.json'),false);
});
test('PATH duplicates are reported and the first executable is probed',()=>{
 const dir=fs.mkdtempSync(path.join(process.cwd(),'.test-path-'));
 try {
  const bins=['first','second'].map(n=>path.join(dir,n));
  for(const bin of bins){fs.mkdirSync(bin);fs.writeFileSync(path.join(bin,'git'),'#!/bin/sh\necho git-test\n',{mode:0o755});}
  const r=run(['--json','--agents','none'],{HOME:dir,PATH:bins.join(path.delimiter)});
  const report=JSON.parse(r.stdout),git=report.tools.find(t=>t.name==='git');
  assert.equal(git.path,path.join(bins[0],'git')); assert.equal(git.alternatives.length,1);
  assert.ok(report.warnings.some(w=>w.startsWith('git:')));
 }finally{fs.rmSync(dir,{recursive:true});}
});
test('manifest refuses a dangling symlink',()=>{
 const dir=fs.mkdtempSync(path.join(process.cwd(),'.test-link-'));
 try{
  const file=path.join(dir,'record.json'),target=path.join(dir,'absent');fs.symlinkSync(target,file);
  assert.notEqual(run(['--manifest',file,'--agents','none'],{PATH:dir}).status,0);
  assert.equal(fs.existsSync(target),false);
 }finally{fs.rmSync(dir,{recursive:true});}
});
test('tool dry-run constructs Homebrew commands without executing installation',()=>{
 const dir=fs.mkdtempSync(path.join(process.cwd(),'.test-tools-'));
 try{
  fs.writeFileSync(path.join(dir,'uname'),'#!/bin/sh\necho Darwin\n',{mode:0o755});
  fs.writeFileSync(path.join(dir,'brew'),'#!/bin/sh\nexit 99\n',{mode:0o755});
  const r=spawnSync('/bin/bash',['tools/install.sh','--dry-run'],{encoding:'utf8',env:{...process.env,PATH:dir}});
  assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/brew install.*ripgrep.*node@24/);
 }finally{fs.rmSync(dir,{recursive:true});}
});
test('standalone tool environment persists paths and is idempotent',()=>{
 const dir=fs.mkdtempSync(path.join(process.cwd(),'.test-env-'));
 try{
  const profile=path.join(dir,'.bashrc');fs.writeFileSync(profile,'# existing\n');
  const env={...process.env,HOME:dir,AGENTENV_STATE_DIR:path.join(dir,'state'),AGENTENV_TOOL_PATH:path.join(dir,'tool bin')};
  const execute=()=>spawnSync(process.execPath,['lib/tools-env.mjs'],{encoding:'utf8',env});
  assert.equal(execute().status,0);const before=fs.readFileSync(profile,'utf8');
  assert.match(before,/# existing/);assert.match(before,/agentenv tools/);
  assert.equal(execute().status,0);assert.equal(fs.readFileSync(profile,'utf8'),before);
  assert.match(fs.readFileSync(path.join(dir,'state','env.sh'),'utf8'),/tool bin/);
 }finally{fs.rmSync(dir,{recursive:true});}
});
test('Linux dry-run selects apt and does not execute packages or downloads',()=>{
 const dir=fs.mkdtempSync(path.join(process.cwd(),'.test-linux-'));
 try{
  for(const [name,body] of Object.entries({uname:'echo Linux',id:'echo 0','apt-get':'exit 99',curl:'exit 99'}))
   fs.writeFileSync(path.join(dir,name),'#!/bin/sh\n'+body+'\n',{mode:0o755});
  const r=spawnSync('/bin/bash',['tools/install.sh','--dry-run'],{encoding:'utf8',env:{...process.env,PATH:dir}});
  assert.equal(r.status,0,r.stderr);assert.match(r.stdout,/apt-get install -y.*fd-find.*python3/);
 }finally{fs.rmSync(dir,{recursive:true});}
});
test('package installation failures stop before shared profile changes',()=>{
 const dir=fs.mkdtempSync(path.join(process.cwd(),'.test-failure-'));
 try{
  fs.writeFileSync(path.join(dir,'uname'),'#!/bin/sh\necho Darwin\n',{mode:0o755});
  fs.writeFileSync(path.join(dir,'brew'),'#!/bin/sh\nexit 42\n',{mode:0o755});
  const r=spawnSync('/bin/bash',['tools/install.sh'],{encoding:'utf8',env:{...process.env,HOME:dir,PATH:dir}});
  assert.equal(r.status,42);assert.equal(fs.existsSync(path.join(dir,'.bashrc')),false);
 }finally{fs.rmSync(dir,{recursive:true});}
});
