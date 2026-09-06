let board = [], filings = [], meta = {};
const $ = (id) => document.getElementById(id);
const safe = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const won = (v) => { const n=Number(v); if(!Number.isFinite(n)) return '-'; if(n>=1e12) return (n/1e12).toFixed(1)+'조'; if(n>=1e8) return (n/1e8).toFixed(1)+'억'; return Math.round(n).toLocaleString('ko-KR'); };
const pct = (v) => { const n=Number(v); if(!Number.isFinite(n)) return '-'; return (n>0?'+':'')+n.toFixed(1)+'%'; };
function dartUrl(no){ return no ? 'https://dart.fss.or.kr/dsaf001/main.do?rcpNo=' + encodeURIComponent(no) : ''; }
async function fetchJsonCompat(url){
  const r = await fetch(url, {cache:'no-store'});
  if(!r.ok) throw new Error(url.split('?')[0]+' HTTP '+r.status);
  let text = await r.text();
  // Legacy Python json.dumps files may contain non-standard NaN/Infinity tokens.
  text = text.replace(/:\s*NaN(?=\s*[,}\]])/g, ':null')
             .replace(/:\s*Infinity(?=\s*[,}\]])/g, ':null')
             .replace(/:\s*-Infinity(?=\s*[,}\]])/g, ':null');
  try { return JSON.parse(text); }
  catch(e) { throw new Error(url.split('?')[0]+' JSON 파싱 실패: '+e.message); }
}
async function load(){
  $('loadState').textContent='데이터 불러오는 중...';
  try {
    const [data,f] = await Promise.all([
      fetchJsonCompat('./data.json?ts='+Date.now()),
      fetchJsonCompat('./filings.json?ts='+Date.now())
    ]);
    meta = data;
    board = Array.isArray(meta.board) ? meta.board : [];
    filings = Array.isArray(f.filings) ? f.filings : [];
    const s=meta.summary||{}, d=meta.discovery||{};
    $('auto').textContent = d.auto_discovered ?? (meta.watchlist||[]).filter(x=>x.source==='auto').length;
    $('total').textContent = board.length;
    $('watch').textContent = board.filter(x=>x.state==='WATCH').length;
    $('research').textContent = board.filter(x=>x.state==='RESEARCH').length;
    $('avoid').textContent = board.filter(x=>x.state==='AVOID').length;
    $('anomaly').textContent = s.data_anomalies ?? board.filter(x=>x.price_status==='ANOMALY').length;
    $('freshness').textContent = '시스템 산출일 '+(s.as_of||'-')+' · 최신 시장가격일 '+(s.price_date_max||board.map(x=>x.price_date).filter(Boolean).sort().slice(-1)[0]||'-');
    $('loadState').textContent='정상 로드 · '+board.length+'개 종목';
    $('loadState').className='ok';
    render(); renderFilings();
  } catch(e) {
    $('loadState').textContent='데이터 로드 실패: '+e.message;
    $('loadState').className='err';
    $('body').innerHTML='<tr><td colspan="12">데이터를 불러오지 못했습니다. '+safe(e.message)+'</td></tr>';
  }
}
function filtered(){
  const q=$('q').value.trim().toLowerCase(), st=$('state').value;
  return board.filter(r=>(!q||String(r.company||'').toLowerCase().includes(q)||String(r.ticker||'').includes(q))&&(!st||r.state===st))
    .sort((a,b)=>Number(b.market_setup_score??b.opportunity_score??0)-Number(a.market_setup_score??a.opportunity_score??0)||Number(a.risk_score??0)-Number(b.risk_score??0));
}
function render(){
  const rows=filtered();
  $('body').innerHTML=rows.map(r=>{
    const u=r.latest_dart_url||dartUrl(r.latest_rcept_no);
    return '<tr>'+
      '<td><b>'+safe(r.company)+'</b><div class="mini">'+safe(r.ticker)+'</div></td>'+
      '<td><span class="badge '+safe(r.state)+'">'+safe(r.state)+'</span></td>'+
      '<td>'+safe(r.market_setup_score??r.opportunity_score??'-')+'</td>'+
      '<td>'+safe(r.risk_score??'-')+'</td>'+
      '<td>'+safe(Number(r.latest_close||0).toLocaleString('ko-KR'))+'</td>'+
      '<td>'+safe(r.price_date||'-')+'</td>'+
      '<td>'+won(r.avg_trading_value_20d_krw)+'</td>'+
      '<td>'+pct(r.return_1d_pct)+'</td>'+
      '<td>'+pct(r.relative_return_5d_pct)+'</td>'+
      '<td>'+safe(r.data_quality||r.price_status||'-')+'</td>'+
      '<td>'+(u?'<a target="_blank" rel="noopener" href="'+safe(u)+'">'+safe(r.latest_relevant_filing||'DART 원문')+'</a>':safe(r.latest_relevant_filing||'-'))+'</td>'+
      '<td>'+safe(r.reasons||'-')+'</td></tr>';
  }).join('');
  const p=board.filter(r=>r.state==='RESEARCH'&&r.price_status==='OK'&&Number(r.avg_trading_value_20d_krw)>=1e9).slice(0,5);
  $('priority').innerHTML=p.length?p.map(r=>'<div class="candidate"><b>'+safe(r.company)+'</b><div class="mini">거래대금 '+won(r.avg_trading_value_20d_krw)+' · 5일 시장대비 '+pct(r.relative_return_5d_pct)+'</div></div>').join(''):'<div class="muted">현재 우선 상세분석 후보 없음</div>';
}
function renderFilings(){
  const q=$('fq').value.trim().toLowerCase();
  const rows=filings.filter(r=>!q||String(r.company||'').toLowerCase().includes(q)||String(r.report_nm||'').toLowerCase().includes(q));
  $('fc').textContent=rows.length+'건';
  $('fbody').innerHTML=rows.map(r=>{const u=dartUrl(r.rcept_no);return '<tr><td>'+safe(r.company)+'</td><td>'+safe(r.ticker)+'</td><td>'+safe(r.report_nm)+'</td><td>'+safe(r.rcept_dt)+'</td><td>'+(u?'<a target="_blank" rel="noopener" href="'+safe(u)+'">원문</a>':'-')+'</td></tr>';}).join('');
}
window.addEventListener('DOMContentLoaded', load);