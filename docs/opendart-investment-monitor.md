# OpenDART Investment Daily Monitor

이 모니터는 공시를 자동 매수신호로 사용하지 않습니다. 매일 장 마감 후 OpenDART 공시와 시장데이터를 결합해 WATCH / RESEARCH / AVOID 후보를 갱신합니다.

## 실행 기준

- 평일 16:10 KST 자동 실행
- OpenDART 최근 21일 주요/정정공시 확인
- Yahoo Finance에서 종가, 1일/5일 수익률, 20일 평균 거래대금 계산
- 20일 평균 거래대금 10억원 미만은 하드 AVOID
- 반복 정정, 공시 집중, 시장대비 하락을 추가 위험/기회 신호로 사용
- WATCH도 매수 명령이 아니며, 실제 진입 전 납입·희석률·최종정정을 재확인

## 결과물

- `daily_decision_board.csv`
- `recent_relevant_filings.csv`
- `summary.json`

GitHub Actions artifact로 14일간 보관합니다.
