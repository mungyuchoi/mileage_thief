
# 마일리지도둑 프로젝트 대화 기록 (ChatGPT with Mungyu)

## 1. 등급 구조
- **이코노미** Lv.1~5
- **비즈니스** Lv.1~5
- **퍼스트** Lv.1~5
- **히든(★ 별등급)**: 특별조건 (운영진 추천 or 최다 기여자)

### 레벨업 조건 예시
| 등급 | 레벨 | 누적 포인트 | 최소 게시글 수 | 최소 댓글 수 |
|-------|-------|------------|----------------|--------------|
| 이코노미 Lv.1~5 | 0~1000+ | 0~12 | 0~30 |
| 비즈니스 Lv.1~5 | 1500~6000 | 15~33 | 35~70 |
| 퍼스트 Lv.1~5 | 8000~22000 | 40~80 | 80~150 |
| 히든 | 운영진 추천 | - | - |

## 2. 등급별 혜택 설계

| 등급 | 검색 기능 | 광고 포인트 이득 | 알림 서비스 | 커뮤니티 기능 |
|------|----------|----------------|-------------|----------------|
| 이코노미 | 기본 검색 | 기본 (전면+2, 보상형+10) | 미제공 | 댓글 가능 |
| 비즈니스 | 검색조건 2개 저장 | 광고 5% 추가 포인트 | 노선 알림 1건 | 댓글 + 뱃지 표시 |
| 퍼스트 | 검색조건 5개 저장 | 광고 10% 추가 포인트 | 노선 알림 3건 | 댓글 + 뱃지 + 테두리 |
| 히든 | 검색조건 무제한 | 광고 20% 추가 포인트 | 알림 무제한 | 댓글 + 뱃지 + 닉네임 강조 |

## 3. 커뮤니티 게시글 카테고리 (보드 ID)

| 보드 ID | 이름 | 설명 |
|---------|-----|------|
| question | 질문 | 마일리지, 발권, 좌석, 카드 관련 질문 |
| deal | 상테크/혜택 | 카드 혜택, 적립, 이벤트 정보 |
| seat_share | 좌석 알림 | 발견된 마일리지 좌석 공유 |
| error_report | 오류 신고 | 앱 사용 오류 및 버그 보고 |
| suggestion | 기능 건의 | 앱/커뮤니티 개선 의견 |
| free | 자유 게시판 | 자유로운 이야기, 항공 경험담 |
| notice | 공지사항 | 운영자 공지 및 이벤트 안내 |

## 4. 데이터 저장 구조

**크롤링 데이터 저장 방식 (시계열, ML 분석 대비)**

디렉토리 구조 예시:

```
content/company/route/yyyy-mmdd-hhmm/uuid/
```

예시:

```
content/dan/icn-jfk/2025-0507-0800/uuid/
content/dan/icn-jfk/2025-0507-1200/uuid/
```

**장점:**
- 시간별 데이터 변동 추적 가능
- ML/딥러닝 분석 시 시계열 데이터셋으로 활용 가능
- 최신 데이터는 사용자 검색에 사용, 오래된 데이터는 Cold Storage로 이관

## 5. 커뮤니티 활성화 혜택 기능 아이디어

- 출석 체크 이벤트 (일일 접속 유도)
- 미션형 이벤트 (게시글/댓글 작성 미션)
- 활동 포인트 랭킹 이벤트 (경품 제공)
- 시즌별 특별 미션 (여름/겨울 한정)
- 좌석 정보 공유 보상 (기여도 리워드)

## 6. ChatGPT ↔ Cursor 연동 방법

- ChatGPT 대화 → Markdown 파일로 저장 → Cursor 프로젝트에 추가
- 파일 이름 예시: `mileage-doduk-notes.md`
- Cursor에서 참고 메모 및 컨텍스트로 활용 가능

---

**마일리지도둑 프로젝트 (Mungyu & ChatGPT)**  
**2025-05-08 기준 대화 요약**
