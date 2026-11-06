import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
for (const custom of [false,true]) test(`entrypoint environments and arguments (custom=${custom})`,()=>{
 const home=fs.mkdtempSync(path.join(process.cwd(),'.test-container-'));
 try {
  const env={...process.env,HOME:home};
  const keys=['AGENTENV_STATE_DIR','CLAUDE_CONFIG_DIR','CODEX_HOME','OPENCODE_CONFIG_DIR'];
  for(const key of [...keys,'XDG_CONFIG_HOME']) delete env[key];
  const dirs=custom?['state space','claude space','codex space','opencode space']:['.local/state/agentenv','.claude','.codex','.config/opencode'];
  if(custom) keys.forEach((k,i)=>env[k]=path.join(home,dirs[i]));
  dirs.forEach((d,i)=>{fs.mkdirSync(path.join(home,d),{recursive:true});fs.writeFileSync(path.join(home,d,'env.sh'),`export LOADED_${i}=yes\n`);});
  const run=args=>spawnSync('/bin/bash',['docker/entrypoint.sh',...args],{env,encoding:'utf8'});
  const r=run([process.execPath,'-e','console.log(JSON.stringify([process.argv.slice(1), [0,1,2,3].map(i=>process.env[`LOADED_${i}`])]))','a b','$(false)','']);
  assert.equal(r.status,0,r.stderr);
  assert.deepEqual(JSON.parse(r.stdout),[['a b','$(false)',''],['yes','yes','yes','yes']]);
  assert.equal(run(['/bin/bash','-c','exit 37']).status,37);
  fs.unlinkSync(path.join(home,dirs[1],'env.sh'));
  assert.notEqual(run(['/bin/true']).status,0);
 }finally{fs.rmSync(home,{recursive:true});}
});
