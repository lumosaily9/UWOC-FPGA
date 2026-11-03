"""Run the amplitude-domain extension RTL tests with Icarus Verilog."""
from pathlib import Path
from hashlib import sha256
import argparse, json, os, re, subprocess
from icarus_paths import executable, windows_tool_paths

ROOT=Path(__file__).resolve().parents[1]

def main():
    ap=argparse.ArgumentParser(description='Run six amplitude-domain RTL regression groups')
    ap.add_argument('--tool-root',default=os.environ.get('ICARUS_HOME'))
    ap.add_argument('--iverilog',default=os.environ.get('IVERILOG'))
    ap.add_argument('--vvp',default=os.environ.get('VVP'))
    args=ap.parse_args()
    home=Path(args.tool_root).expanduser().resolve() if args.tool_root else None
    compiler=executable('iverilog',args.iverilog,home)
    runtime=executable('vvp',args.vvp,home)
    logs=ROOT/'sim/results/extensions';logs.mkdir(parents=True,exist_ok=True)
    outputs=ROOT/'build/results/extension_sim';outputs.mkdir(parents=True,exist_ok=True)
    results={}
    def run(argv,filename):
        argv=list(map(str,argv))
        display_argv=argv.copy()
        if Path(argv[0]).is_absolute():
            try:display_argv[0]=Path(argv[0]).relative_to(ROOT).as_posix()
            except ValueError:display_argv[0]=Path(argv[0]).name
        def write_log(exit_code,stdout,stderr):
            def stream(value):
                if isinstance(value,bytes):value=value.decode('utf-8',errors='replace')
                return value.rstrip('\n') if value else '(no output)'
            content=(f'command: {subprocess.list2cmdline(display_argv)}\n'
                     f'cwd: . (project root)\nexit_code: {exit_code}\n\n'
                     f'[stdout]\n{stream(stdout)}\n\n[stderr]\n{stream(stderr)}\n')
            (logs/filename).write_text(content.replace(str(ROOT),'.').replace(ROOT.as_posix(),'.'),encoding='utf-8')
        try:
            p=subprocess.run(argv,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
        except subprocess.TimeoutExpired as exc:
            write_log('unavailable (timed out after 90 seconds)',exc.stdout,exc.stderr)
            raise
        except OSError as exc:
            write_log('unavailable (process did not start)','',str(exc))
            raise
        write_log(p.returncode,p.stdout,p.stderr)
        cleaned=(p.stdout+p.stderr).replace(str(ROOT),'.').replace(ROOT.as_posix(),'.')
        if p.returncode:raise RuntimeError(filename+' failed\n'+p.stdout+p.stderr)
        return cleaned
    with windows_tool_paths(compiler,runtime) as (cc,sim):
        version=run([cc,'-V'],'tool_version.log').splitlines()[0]
        rtl=sorted((ROOT/'src/pl/extensions').glob('*.sv'))
        for top in ['tb_ook','tb_ffe','tb_capacity','tb_control','tb_overflow','tb_overflow_pipeline']:
            tb='tb_ook.sv' if top in ['tb_ook','tb_ffe','tb_capacity'] else top+'.sv'
            obj=outputs/(top+'.vvp')
            run([cc,'-g2012','-Wall','-s',top,'-o',obj,*rtl,ROOT/'sim/extensions'/tb],top+'_compile.log')
            log=run([sim,obj],top+'.log')
            if 'RESULT' not in log or 'FAIL ' in log:raise RuntimeError(top+' has no passing result')
            results[top]={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',log)}
            print(log.strip())
    report={'status':'PASS','test_kind':'amplitude_domain_rtl_simulation','simulator':version,
            'checks':results,'configuration':json.loads((ROOT/'data/config/project.json').read_text(encoding='utf-8'))['amplitude_extension'],
            'source_sha256':{p.relative_to(ROOT).as_posix():sha256(p.read_bytes()).hexdigest() for p in rtl}}
    (logs/'summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return 0

if __name__=='__main__':
    raise SystemExit(main())
