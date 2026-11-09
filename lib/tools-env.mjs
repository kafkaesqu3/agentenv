import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { randomUUID } from 'node:crypto';

const args = process.argv.slice(2);
if (args.length && (args.length !== 2 || args[0] !== '--profile')) throw new Error('Expected --profile FILE');
const home = os.homedir();
const state = path.resolve(process.env.AGENTENV_STATE_DIR || path.join(home,'.local','state','agentenv'));
const bins = [path.dirname(process.execPath), ...(process.env.AGENTENV_TOOL_PATH || '').split(path.delimiter).filter(Boolean)];
const quote = value => `'${value.replaceAll("'", "'\\''")}'`;
const psquote = value => `'${value.replaceAll("'", "''")}'`;
function read(file) {
  let stat;
  try { stat=fs.lstatSync(file); } catch(e) { if(e.code==='ENOENT') return ''; throw e; }
  if(stat.isSymbolicLink()) throw new Error(`Refusing symlink: ${file}`);
  const bytes=fs.readFileSync(file);
  if(bytes[0]===0xff && bytes[1]===0xfe) return bytes.subarray(2).toString('utf16le');
  if(bytes[0]===0xfe && bytes[1]===0xff) return Buffer.from(bytes.subarray(2)).swap16().toString('utf16le');
  return new TextDecoder('utf-8',{fatal:true}).decode(bytes);
}
function write(file, text) {
  const old=read(file);
  if(old===text && fs.existsSync(file)) return;
  fs.mkdirSync(path.dirname(file),{recursive:true});
  if(fs.existsSync(file)) {
    const backup=`${file}.bak.${Date.now()}.${randomUUID()}`;
    fs.copyFileSync(file,backup,fs.constants.COPYFILE_EXCL);fs.chmodSync(backup,0o600);
  }
  const temp=`${file}.tmp.${randomUUID()}`;
  try {
    fs.writeFileSync(temp,(file.endsWith('.ps1')?'\ufeff':'')+text,{mode:0o600,flag:'wx'});
    fs.renameSync(temp,file);
  } finally {if(fs.existsSync(temp))fs.unlinkSync(temp);}
}
if (!args.length) write(path.join(state,'env.sh'),`# Shared tool paths; source in noninteractive launchers.\nexport PATH=${quote(bins.join(path.delimiter))}:"$PATH"\n`);
if (args.length) write(path.join(state,'env.ps1'),`# Shared tool paths.\n$env:PATH = ${psquote(bins.join(path.delimiter))} + [IO.Path]::PathSeparator + $env:PATH\n`);
const begin='# >>> agentenv tools >>>',end='# <<< agentenv tools <<<';
const profiles=args.length?[args[1]]:['.bashrc','.zshrc','.profile'].map(n=>path.join(home,n));
if(!args.length) for(const name of ['.bash_profile','.bash_login']) {const f=path.join(home,name);if(fs.existsSync(f)){profiles.push(f);break;}}
for(const file of profiles) {
  const old=read(file),start=old.indexOf(begin),finish=old.indexOf(end,start);
  if(start!==-1 && finish===-1) throw new Error(`Incomplete agentenv tools block: ${file}`);
  const body=args.length?`. ${psquote(path.join(state,'env.ps1'))}`:`. ${quote(path.join(state,'env.sh'))}`;
  const block=`${begin}\n${body}\n${end}`;
  write(file,start===-1?old+(old&&!old.endsWith('\n')?'\n':'')+block+'\n':old.slice(0,start)+block+old.slice(finish+end.length));
}
