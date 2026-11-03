"""Check portable Vivado source paths and 20 Mbit/s parameter consistency."""
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
NS={'s':'http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009'}

def main():
    failures=[]
    checks={'project_files':0,'ip_source_files':0,'rom_references':0,'serial_parameters':0}
    for role in ('tx','rx'):
        project=ROOT/'src/pl'/role
        name='uwoc_'+role
        xpr=ET.parse(project/(name+'.xpr'))
        for node in xpr.findall('.//File'):
            value=node.get('Path','').replace('\\','/')
            value=value.replace('$PSRCDIR',str(project/(name+'.srcs')))
            value=value.replace('$PPRDIR',str(project))
            checks['project_files']+=1
            if '$' in value or not Path(value).is_file():failures.append('missing project file: '+value)
        bd_path=next(project.rglob('*.bd'))
        design=json.loads(bd_path.read_text(encoding='utf-8'))['design']
        cell='fifo2uart_v2_0' if role=='tx' else 'uart2fifo_v2_0'
        params=design['components'][cell]['parameters']
        for param,expected in [('CLK_FREQ','200000000'),('BAUD_RATE','20000000')]:
            checks['serial_parameters']+=1
            if params[param]['value']!=expected:failures.append(role+': incorrect '+param)
        for cell_config in design['components'].values():
            for key,value in cell_config.get('parameters',{}).items():
                if key.lower()=='coe_file':
                    checks['rom_references']+=1
                    if not (bd_path.parent/value['value']).is_file():failures.append('missing BD ROM: '+value['value'])
        for xci_path in project.rglob('*.xci'):
            xci=ET.parse(xci_path)
            for node in xci.iter():
                if node.text and node.text.lower().endswith('.coe'):
                    checks['rom_references']+=1
                    if not (xci_path.parent/node.text).is_file():failures.append('missing XCI ROM: '+node.text)
                rid=node.get('{'+NS['s']+'}referenceId','')
                if rid.endswith('.BAUD_RATE'):
                    checks['serial_parameters']+=1
                    if node.text!='20000000':failures.append('incorrect XCI serial rate: '+str(xci_path.relative_to(ROOT)))
    for component in (ROOT/'src/ip_repo').glob('*/component.xml'):
        xml=ET.parse(component)
        for node in xml.findall('.//s:file/s:name',NS):
            checks['ip_source_files']+=1
            if not (component.parent/node.text).is_file():failures.append('missing IP source: '+node.text)
    for folder in (ROOT/'src/pl',ROOT/'src/ip_repo',ROOT/'data/tx',ROOT/'data/rx'):
        for p in folder.rglob('*'):
            if p.is_file():
                if not all(re.fullmatch(r'[a-z0-9_.-]+',x) for x in p.relative_to(ROOT).parts):failures.append('non-portable file name: '+str(p.relative_to(ROOT)))
                if p.suffix in ('.xml','.xci','.xpr','.bd','.v','.xdc','.tcl'):
                    text=p.read_text(encoding='utf-8')
                    if re.search(r'[a-zA-Z]:[/\\](?:users|xilinx|fpga)',text,re.I):failures.append('machine-specific path: '+str(p.relative_to(ROOT)))
    report={'status':'pass' if not failures else 'fail','kind':'static_source_checks','checks':checks,'failures':failures}
    out=ROOT/'build/results/source_checks.json';out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))
    if failures:raise SystemExit(1)

if __name__=='__main__':main()
