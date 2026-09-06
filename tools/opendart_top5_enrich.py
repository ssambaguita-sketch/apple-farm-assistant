import csv,json,os,time
from datetime import date,timedelta
from urllib.parse import urlencode
from urllib.request import Request,urlopen

KEY=os.environ['OPENDART_API_KEY'].strip()
BASE='https://opendart.fss.or.kr/api/'
TARGETS=['블루산업개발','한국유니온제약','MSDI','CSA 코스믹','애드바이오텍']
END=date.today(); START=END-timedelta(days=89)

def call(path,params):
    q=dict(params); q['crtfc_key']=KEY
    req=Request(BASE+path+'?'+urlencode(q),headers={'User-Agent':'OpenDARTTop5Enricher/1.0'})
    with urlopen(req,timeout=25) as r: return json.loads(r.read().decode('utf-8'))

def get_codes():
    found={}; page=1
    while len(found)<len(TARGETS):
        d=call('list.json',{'bgn_de':START.strftime('%Y%m%d'),'end_de':END.strftime('%Y%m%d'),'page_no':page,'page_count':100,'sort':'date','sort_mth':'asc'})
        if d.get('status')!='000': break
        for x in d.get('list') or []:
            n=x.get('corp_name')
            if n in TARGETS: found[n]=x.get('corp_code')
        if page>=int(d.get('total_page') or 1): break
        page+=1
    return found

API={'유상증자':'piicDecsn.json','전환사채':'cvbdIsDecsn.json','감자':'crDecsn.json'}

def family(row):
    t=row.get('report_nm','')
    if '유상증자' in t:return '유상증자'
    if '전환사채' in t:return '전환사채'
    if '감자' in t:return '감자'
    return None

def main():
    os.makedirs('artifacts_top5',exist_ok=True)
    codes=get_codes(); allrows=[]
    for name,code in codes.items():
        for fam,path in API.items():
            d=call(path,{'corp_code':code,'bgn_de':START.strftime('%Y%m%d'),'end_de':END.strftime('%Y%m%d')})
            if d.get('status')=='000':
                for x in d.get('list') or []:
                    x=dict(x); x['event_family']=fam; allrows.append(x)
            time.sleep(.15)
    allrows=[r for r in allrows if r.get('corp_name') in TARGETS]
    with open('artifacts_top5/top5_details.jsonl','w',encoding='utf-8') as f:
        for r in allrows:f.write(json.dumps(r,ensure_ascii=False)+'\n')
    keys=sorted({k for r in allrows for k in r})
    with open('artifacts_top5/top5_details.csv','w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=keys); w.writeheader(); w.writerows(allrows)
    summary={'period_start':str(START),'period_end':str(END),'corp_codes_found':codes,'rows':len(allrows)}
    with open('artifacts_top5/summary.json','w',encoding='utf-8') as f:json.dump(summary,f,ensure_ascii=False,indent=2)
    print(json.dumps({'rows':len(allrows),'companies':list(codes)},ensure_ascii=False))
if __name__=='__main__':main()
