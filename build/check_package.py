"""Check the submission folder structure, names, configuration and scripts."""
from pathlib import Path
import ast, json, re

ROOT=Path(__file__).resolve().parents[1]
SKIP={'.git','__pycache__','.xil'}

def main():
    errors=[]
    required=['README.md','src','sim','build','board','data','skill/README.md','report',
              'src/pl/tx/uwoc_tx.xpr','src/pl/rx/uwoc_rx.xpr','src/ip_repo',
              'src/ps/rx/main.c','src/ps/tx_fsbl/main.c','build/open_project.tcl',
              'build/build_project.tcl','build/build_ps.tcl','build/run_sim.py',
              'build/run_extension_sim.py','board/receive_udp.py',
              'data/config/project.json','report/technical_report.docx',
              'report/flow_diagrams.pptx','report/ai_collaboration.md']
    for item in required:
        if not (ROOT/item).exists():errors.append('Missing path: '+item)
    python_count=0;file_count=0
    for p in ROOT.rglob('*'):
        rel=p.relative_to(ROOT)
        if any(x in SKIP for x in rel.parts):continue
        if not all(x=='README.md' or re.fullmatch(r'[a-z0-9_.-]+',x) for x in rel.parts):
            errors.append('Invalid file name: '+rel.as_posix())
        if p.is_file():file_count+=1
        if p.is_file() and p.suffix=='.py':
            python_count+=1
            try:ast.parse(p.read_text(encoding='utf-8-sig'),filename=rel.as_posix())
            except (SyntaxError,UnicodeError) as e:errors.append(str(e))
    conf=ROOT/'data/config/project.json'
    if conf.exists():
        c=json.loads(conf.read_text(encoding='utf-8'));m=c['main_link']
        if m['bit_rate_bps']!=20000000 or m['pl_clock_hz']!=200000000 or m['clocks_per_bit']!=10:
            errors.append('The main link must use 20 Mbps / 200 MHz / 10 clocks per bit')
        if m['rs_n']!=255 or m['rs_k']!=239:errors.append('Unexpected RS code parameters')
    result={'status':'PASS' if not errors else 'FAIL','required_paths':len(required),
            'file_count':file_count,'python_files_checked':python_count,'errors':errors}
    out=ROOT/'build/results/package_checks.json';out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))
    return bool(errors)

if __name__=='__main__':raise SystemExit(main())
