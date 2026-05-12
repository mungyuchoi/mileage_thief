# Admin & Operations Architecture

최종 업데이트: 2026-05-10

이 문서는 마일캐치 관리자 기능을 다른 프로젝트에 바로 이식할 수 있도록 정리한 운영 아키텍처 가이드다. 커뮤니티의 원본 게시글/댓글 구조는 `docs/COMMUNITY.md`를 기준으로 하고, 이 문서는 관리자 진입, 신고 처리, 이용금지, 땅콩 지급, 콘텐츠 운영, 광고/콘테스트/카드/상품권 URL 관리, 감사 로그를 다룬다.

## 설계 원칙

- 관리자 권한은 `users/{uid}.roles`로 판정한다.
- 앱 UI 노출만으로 권한을 보장하지 않는다. 민감한 쓰기는 Firestore Rules 또는 Cloud Functions에서 다시 검증한다.
- 신고는 원본 하위 신고, 전역 운영 큐, 사용자 신고 내역을 함께 기록한다.
- 관리자 액션은 대상 문서뿐 아니라 `admin/audit_logs/{logId}`에 남기는 것을 새 프로젝트 기본값으로 둔다.
- 이용금지는 사용자 문서의 `isBanned`를 단일 기준으로 사용한다.
- 땅콩 지급/차감은 `users/{uid}.peanutCount`와 `users/{uid}/peanut_history/{historyId}`를 함께 갱신한다.
- 게시글/댓글/채팅 메시지는 hard delete보다 `isHidden`, `isDeleted`, 상태 필드 기반의 soft moderation을 우선한다.
- 현재 마일캐치 구현처럼 클라이언트 화면에서 직접 쓰는 흐름도 가능하지만, 새 프로젝트에서는 callable/server action으로 감싸는 것을 권장한다.

## 관리자 권한 모델

기본 사용자:

```json
{
  "uid": "user_abc",
  "roles": ["user"],
  "isBanned": false
}
```

관리자:

```json
{
  "uid": "admin_abc",
  "roles": ["user", "admin"],
  "isBanned": false
}
```

소유자:

```json
{
  "uid": "owner_abc",
  "roles": ["user", "owner"],
  "isBanned": false
}
```

권한 판정 규칙:

| roles 형태 | 관리자 판정 |
| --- | --- |
| `["user", "admin"]` | admin |
| `["user", "owner"]` | owner |
| `{ "admin": true }` | admin |
| `{ "owner": true }` | owner |
| `"admin"` | admin |
| `"owner"` | owner |

새 프로젝트 기본값은 배열 형태다. Map/String 형태는 기존 데이터 호환용으로만 허용한다.

권장 권한 레벨:

| 권한 | 용도 |
| --- | --- |
| `user` | 일반 사용자 |
| `admin` | 신고 처리, 게시글 숨김, 사용자 제재, 운영 콘텐츠 관리 |
| `owner` | 관리자 권한 부여/회수, 위험한 삭제, 시스템 설정 |
| `branch` | 지점 관리처럼 특정 도메인 운영자 |

관리자 페이지 노출 조건:

- 로그인 사용자의 `users/{uid}`를 읽는다.
- `roles`에 `admin` 또는 `owner`가 있으면 설정/프로필 영역에 관리자 페이지 진입 버튼을 노출한다.
- 마일캐치 현재 구조에서는 홈 설정 화면에서 `AdminPageScreen`으로 진입한다.
- 타 사용자 프로필 화면에서는 관리자에게 땅콩 지급과 이용금지 토글을 노출한다.

서버 검증 권장:

```text
request.auth.uid -> users/{uid}.roles 조회 -> admin/owner 확인 -> 운영 쓰기 허용
```

Cloud Functions에서는 `hasAdminRole(roles)` 공통 함수를 두고 모든 callable에서 재사용한다.

## 관리자 페이지 IA

현재 마일캐치의 `AdminPageScreen`은 관리자 기능의 허브다.

| 메뉴 | 현재 화면 | 목적 |
| --- | --- | --- |
| 통계 대시보드 | `AdminStatsDashboardScreen` | 사용자, 게시글, 신고, 콘테스트, 카드 현황 요약 |
| 기간별 통계 | `AdminPeriodStatsScreen` | 7/30/90일 활동량, 신고량, 인기 게시판 확인 |
| 인기 콘텐츠 | `AdminPopularContentScreen` | 좋아요/댓글/조회 기반 인기 게시글 확인 |
| 사용자 관리 | `AdminUserManageScreen` | 사용자 목록, 프로필 이동, 이용금지/해제 |
| 게시글 관리 | `AdminPostManageScreen` | 게시글 조회, 숨김/숨김해제, 삭제/복구 |
| 광고 관리 | `AdManageScreen` | 앱 진입/가이드 배너 광고 관리 |
| 콘테스트 관리 | `ContestManageScreen` | 콘테스트 생성, 수정, 삭제 |
| 신고 관리 | `AdminReportManageScreen` | 게시글/댓글/채팅 신고 처리 |
| 카드 DB 관리 | `CardCatalogScreen` | 카드 상품 DB, 요청, import/reject, revision 관리 |
| 상품권 특가 URL 관리 | `AdminGiftcardDealSourceScreen` | 특가 URL source, 사용자 요청, 크롤링 상태 관리 |

새 프로젝트에서 최소 관리자 페이지는 다음 4개부터 시작한다.

1. 신고 관리
2. 사용자 관리
3. 게시글 관리
4. 운영 로그

통계, 광고, 콘테스트, 카드 DB, 상품권 URL 관리는 도메인 기능이 붙은 뒤 확장한다.

## 운영 컬렉션 맵

| 경로 | 역할 |
| --- | --- |
| `users/{uid}` | 권한, 이용금지, 땅콩, 사용자 카운터 |
| `users/{uid}/reports/{reportId}` | 사용자가 제출한 신고 내역 |
| `users/{uid}/peanut_history/{historyId}` | 땅콩 지급/사용 이력 |
| `reports/posts/posts/{reportId}` | 게시글 신고 전역 운영 큐 |
| `reports/comments/comments/{reportId}` | 댓글 신고 전역 운영 큐 |
| `reports/chat_messages/messages/{reportId}` | 채팅 메시지 신고 전역 운영 큐 |
| `posts/{date}/posts/{postId}/reports/{reporterUid}` | 게시글별 신고 중복 방지와 상세 |
| `posts/{date}/posts/{postId}/comments/{commentId}/reports/{reporterUid}` | 댓글별 신고 중복 방지와 상세 |
| `chat_rooms/{roomId}/messages/{messageId}/reports/{reporterUid}` | 채팅 메시지별 신고 중복 방지와 상세 |
| `admin/audit_logs/{logId}` | 관리자 액션 감사 로그 |
| `admin/deleted_posts/{postId}` | 삭제 처리 전 게시글 백업 권장 |
| `admin/flagged_users/{uid}` | 반복 문제 사용자 요약 권장 |
| `admin/board_settings/{boardId}` | 운영자용 게시판 설정 권장 |
| `admin/system_logs/{logId}` | 서버/배치 시스템 로그 권장 |
| `bottom_sheet_ads/{adId}` | 앱 진입/가이드 광고 |
| `contests/{contestId}` | 콘테스트 메타와 운영 |
| `cards/{catalogId}/cardProducts/{cardId}` | 카드 DB 상품 |
| `cards/{catalogId}/cardRequests/{requestId}` | 사용자 카드 요청 |
| `giftcardDealSources/{sourceId}` | 상품권 특가 크롤링 URL |
| `giftcardDealSourceRequests/{requestId}` | 사용자가 제안한 특가 URL |
| `giftcardDeals/{dealId}` | 노출용 상품권 특가 |
| `giftcardDeals/{dealId}/priceHistory/{historyId}` | 상품권 특가 가격 히스토리 |

## 운영 로그와 감사

새 프로젝트에서는 모든 관리자 변경에 감사 로그를 남긴다. 현재 앱의 일부 화면은 대상 문서에 `hiddenBy`, `bannedBy`, `adminDeletedBy` 같은 필드를 직접 남기고 있다. 이 방식에 더해 중앙 감사 로그를 두는 것을 권장한다.

경로:

```text
admin/audit_logs/{logId}
```

예시:

```json
{
  "action": "report.hide_target",
  "actorUid": "admin_abc",
  "actorName": "운영자",
  "targetType": "post",
  "targetPath": "posts/20250609/posts/abc123",
  "targetOwnerUid": "user_def",
  "reportId": "report_123",
  "reason": "spam",
  "memo": "광고성 게시글 반복 신고",
  "before": {
    "isHidden": false,
    "reportsCount": 5
  },
  "after": {
    "isHidden": true,
    "hiddenByReport": true
  },
  "createdAt": "serverTimestamp",
  "client": {
    "platform": "app",
    "appVersion": "1.0.0"
  }
}
```

감사 로그 필수 액션:

- 신고 상태 변경
- 신고 대상 숨김 처리
- 게시글 숨김/숨김해제
- 게시글 삭제/복구
- 댓글 숨김/복구
- 채팅 메시지 숨김
- 사용자 이용금지/해제
- 땅콩 지급/차감
- 관리자 권한 부여/회수
- 광고 생성/수정/삭제
- 콘테스트 생성/수정/삭제/수상자 선정
- 카드 DB import/reject/rollback
- 상품권 URL 요청 승인/반려

## 신고 데이터 모델

신고 문서는 세 위치에 기록한다.

1. 원본 하위 reports: 중복 신고 방지와 대상 상세 화면에서 신고 여부 확인
2. 전역 reports 큐: 관리자 신고 목록
3. 사용자 reports: 사용자가 본인 신고 내역을 확인

게시글 신고 전역 문서:

```json
{
  "reportId": "report_123",
  "reportPath": "reports/posts/posts/report_123",
  "userReportPath": "users/reporter_abc/reports/report_123",
  "type": "post",
  "reason": "spam",
  "detail": "광고성 링크가 반복됩니다.",
  "reporterUid": "reporter_abc",
  "reporterName": "신고자",
  "reportedAt": "serverTimestamp",
  "status": "pending",
  "postId": "abc123",
  "postNumber": "12345",
  "dateString": "20250609",
  "boardId": "deal",
  "postTitle": "상테크 카드 추천",
  "postAuthor": {
    "uid": "user_def",
    "displayName": "작성자"
  },
  "detailPath": "posts/20250609/posts/abc123"
}
```

댓글 신고 전역 문서:

```json
{
  "reportId": "report_456",
  "reportPath": "reports/comments/comments/report_456",
  "userReportPath": "users/reporter_abc/reports/report_456",
  "type": "comment",
  "reason": "abuse",
  "detail": "욕설이 포함되어 있습니다.",
  "reporterUid": "reporter_abc",
  "reporterName": "신고자",
  "reportedAt": "serverTimestamp",
  "status": "pending",
  "postId": "abc123",
  "postNumber": "12345",
  "dateString": "20250609",
  "commentId": "cmt789",
  "commentAuthor": {
    "uid": "user_def",
    "displayName": "작성자"
  },
  "commentContent": "<p>댓글 내용</p>",
  "detailPath": "posts/20250609/posts/abc123/comments/cmt789"
}
```

채팅 신고 전역 문서:

```json
{
  "reportId": "report_789",
  "reportPath": "reports/chat_messages/messages/report_789",
  "userReportPath": "users/reporter_abc/reports/report_789",
  "type": "chat_message",
  "reason": "abuse",
  "detail": "채팅방에서 욕설",
  "reporterUid": "reporter_abc",
  "reporterName": "신고자",
  "reportedAt": "serverTimestamp",
  "status": "pending",
  "roomId": "global",
  "messageId": "msg123",
  "messageAuthor": {
    "uid": "user_def",
    "displayName": "작성자"
  },
  "messageText": "신고 대상 메시지",
  "imageUrls": [],
  "detailPath": "chat_rooms/global/messages/msg123"
}
```

신고 상태:

| status | 의미 |
| --- | --- |
| `pending` | 접수됨, 아직 처리 전 |
| `reviewed` | 운영자가 검토했지만 조치 보류 |
| `resolved` | 숨김, 제재 등 조치 완료 |
| `rejected` | 신고 기각 |

신고 사유:

| 값 | 설명 |
| --- | --- |
| `abuse` | 욕설/비방 |
| `spam` | 도배/광고 |
| `sexual` | 음란/선정성 |
| `hate` | 혐오/차별 |
| `etc` | 기타 |

## 신고 접수 플로우

게시글 신고:

```text
set posts/{date}/posts/{postId}/reports/{reporterUid}
set reports/posts/posts/{reportId}
set users/{reporterUid}/reports/{reportId}
update posts/{date}/posts/{postId}.reportsCount += 1
```

댓글 신고:

```text
set posts/{date}/posts/{postId}/comments/{commentId}/reports/{reporterUid}
set reports/comments/comments/{reportId}
set users/{reporterUid}/reports/{reportId}
update posts/{date}/posts/{postId}/comments/{commentId}.reportsCount += 1
```

채팅 메시지 신고:

```text
set chat_rooms/{roomId}/messages/{messageId}/reports/{reporterUid}
set reports/chat_messages/messages/{reportId}
set users/{reporterUid}/reports/{reportId}
update chat_rooms/{roomId}/messages/{messageId}.reportsCount += 1
```

중복 방지:

- 원본 하위 reports 문서 ID를 `reporterUid`로 고정한다.
- 같은 사용자가 같은 대상을 다시 신고하면 기존 문서 존재 여부로 차단한다.
- 전역 report ID는 자동 ID를 사용한다.

## 신고 처리 플로우

신고 관리 화면은 전역 큐를 읽는다.

```text
reports/posts/posts orderBy reportedAt desc limit 200
reports/comments/comments orderBy reportedAt desc limit 200
reports/chat_messages/messages orderBy reportedAt desc limit 200
```

검토 완료:

```text
merge reports/{kind}/{collection}/{reportId}
merge targetPath/reports/{reporterUid}
merge users/{reporterUid}/reports/{reportId}
set status = reviewed
set reviewedAt, reviewedBy
create admin/audit_logs
```

처리 완료:

```text
set status = resolved
set resolvedAt, resolvedBy
create admin/audit_logs
```

기각:

```text
set status = rejected
set rejectedAt, rejectedBy
create admin/audit_logs
```

숨김 처리:

```text
merge {detailPath} {
  isHidden: true,
  hiddenByReport: true,
  hiddenReportId: reportId,
  hiddenAt: serverTimestamp,
  hiddenBy: adminUid,
  updatedAt: serverTimestamp
}

merge report copies {
  status: resolved,
  action: hidden,
  resolvedAt: serverTimestamp,
  resolvedBy: adminUid,
  updatedAt: serverTimestamp
}

create admin/audit_logs
```

자동 숨김 권장:

- 게시글 신고 5회 이상이면 `isHidden=true`, `hiddenByReport=true`
- 댓글 신고 6회 이상이면 `isHidden=true`, `hiddenByReport=true`
- 자동 처리도 감사 로그를 남기고 `actorUid`는 `system`으로 기록한다.

## 사용자 관리와 이용금지

사용자 관리 화면 조회:

```text
users orderBy lastLoginAt desc limit 200
```

사용자 카드에서 표시할 필드:

- `displayName`
- `email`
- `photoURL`
- `displayGrade`
- `peanutCount`
- `postsCount`
- `commentCount`
- `lastLoginAt`
- `isBanned`

이용금지 처리:

```json
{
  "isBanned": true,
  "bannedAt": "serverTimestamp",
  "bannedBy": "admin_abc",
  "banReason": "신고 누적",
  "updatedAt": "serverTimestamp"
}
```

이용금지 해제:

```json
{
  "isBanned": false,
  "banReleasedAt": "serverTimestamp",
  "banReleasedBy": "admin_abc",
  "banReleaseReason": "재검토 후 해제",
  "updatedAt": "serverTimestamp"
}
```

앱에서 막아야 하는 기능:

- 게시글 작성 FAB 노출
- 게시글 작성 저장
- 댓글 작성
- 채팅 메시지 전송
- 이미지 업로드가 포함된 커뮤니티 쓰기
- 신고 남용 방지를 위해 필요하면 신고 작성도 제한

읽기 권한은 유지하는 것을 기본으로 한다. 완전 차단이 필요한 경우 `banLevel`을 별도로 둔다.

권장 ban 확장:

```json
{
  "isBanned": true,
  "banLevel": "write_only",
  "banUntil": null,
  "banReason": "abuse",
  "banMemo": "욕설 반복",
  "bannedAt": "serverTimestamp",
  "bannedBy": "admin_abc"
}
```

`banLevel` 예시:

| 값 | 의미 |
| --- | --- |
| `write_only` | 쓰기만 제한 |
| `community` | 커뮤니티/채팅 제한 |
| `full` | 앱 주요 기능 제한 |

## 땅콩 지급과 회수

마일캐치 현재 구조는 타 사용자 프로필에서 관리자가 땅콩을 지급할 수 있다. 새 프로젝트에서는 Cloud Function으로 감싸고 감사 로그를 필수로 남긴다.

지급 batch:

```text
update users/{targetUid}.peanutCount += amount
set users/{targetUid}/peanut_history/{historyId}
set admin/audit_logs/{logId}
```

`peanut_history` 예시:

```json
{
  "type": "admin_gift",
  "amount": 30,
  "adminId": "admin_abc",
  "adminName": "마일캐치",
  "reason": "이벤트 보상",
  "createdAt": "serverTimestamp"
}
```

감사 로그 예시:

```json
{
  "action": "user.peanut_grant",
  "actorUid": "admin_abc",
  "targetType": "user",
  "targetPath": "users/user_def",
  "targetOwnerUid": "user_def",
  "amount": 30,
  "reason": "이벤트 보상",
  "createdAt": "serverTimestamp"
}
```

정책:

- 지급 amount는 양수만 허용한다.
- 회수는 `type: "admin_adjust"` 또는 `type: "admin_revoke"`처럼 별도 타입으로 기록한다.
- 지급/회수는 현재 잔액을 transaction으로 읽고 계산한다.
- UI에는 운영자 선물을 클릭 불가 히스토리로 표시한다.

## 게시글 관리

게시글 관리 화면 조회:

```text
collectionGroup("posts")
orderBy createdAt desc
limit 200
```

관리 카드 표시:

- 제목
- 본문 요약
- 게시판
- 작성자
- 작성일
- 좋아요/댓글/조회/신고 수
- `isHidden`
- `isDeleted`

숨김 처리:

```json
{
  "isHidden": true,
  "hiddenAt": "serverTimestamp",
  "hiddenBy": "admin_abc",
  "updatedAt": "serverTimestamp"
}
```

숨김 해제:

```json
{
  "isHidden": false,
  "unhiddenAt": "serverTimestamp",
  "unhiddenBy": "admin_abc",
  "updatedAt": "serverTimestamp"
}
```

삭제 처리:

```json
{
  "isDeleted": true,
  "adminDeletedAt": "serverTimestamp",
  "adminDeletedBy": "admin_abc",
  "updatedAt": "serverTimestamp"
}
```

복구:

```json
{
  "isDeleted": false,
  "restoredAt": "serverTimestamp",
  "restoredBy": "admin_abc",
  "updatedAt": "serverTimestamp"
}
```

웹 lookup 동기화:

- 게시글에 `postNumber`가 있으면 `post_numbers/{postNumber}.isDeleted`와 `isHidden`도 함께 갱신한다.
- 삭제 처리된 공개 URL은 404 대신 삭제 안내 페이지를 보여준다.

## 댓글과 채팅 메시지 관리

댓글은 신고 처리 화면에서 `detailPath`를 통해 숨김 처리한다. 별도 댓글 관리 화면을 만들 경우 다음 쿼리를 사용한다.

```text
collectionGroup("comments")
orderBy createdAt desc
limit 200
```

댓글 숨김:

```json
{
  "isHidden": true,
  "hiddenAt": "serverTimestamp",
  "hiddenBy": "admin_abc",
  "updatedAt": "serverTimestamp"
}
```

채팅 메시지 신고는 메시지 단위로 관리한다.

```text
chat_rooms/{roomId}/messages/{messageId}
chat_rooms/{roomId}/messages/{messageId}/reports/{reporterUid}
reports/chat_messages/messages/{reportId}
```

채팅 메시지 숨김 권장 필드:

```json
{
  "isHidden": true,
  "hiddenByReport": true,
  "hiddenReportId": "report_789",
  "hiddenAt": "serverTimestamp",
  "hiddenBy": "admin_abc",
  "updatedAt": "serverTimestamp"
}
```

## 광고 관리

경로:

```text
bottom_sheet_ads/{adId}
```

필드:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `title` | string | 광고 제목 |
| `imageUrl` | string | Storage 업로드 후 다운로드 URL |
| `linkType` | string | `web` 또는 `deeplink` |
| `linkValue` | string | URL 또는 앱 딥링크 |
| `isActive` | boolean | 활성 여부 |
| `startAt` | timestamp/null | 시작 시각 |
| `endAt` | timestamp/null | 종료 시각 |
| `priority` | number | 노출 우선순위 |
| `createdAt` | timestamp | 생성 시각 |
| `updatedAt` | timestamp | 수정 시각 |

관리 액션:

- 광고 생성
- 광고 수정
- 활성/비활성 토글
- 광고 삭제
- 이미지 Storage 삭제
- 특정 사용자 광고 숨김 상태 초기화: `users/{uid}.hideBottomSheetAdUntil` 삭제

새 프로젝트 권장:

- 광고 쓰기는 관리자 callable로 감싼다.
- 이미지는 `bottom_sheet_ads/{adId}_{timestamp}.jpg` 경로에 저장한다.
- 삭제 시 Firestore 문서와 Storage 파일을 함께 정리한다.

## 콘테스트 관리

경로:

```text
contests/{contestId}
contests/{contestId}/submissions/{submissionId}
contests/{contestId}/winners/{rank}
users/{uid}/contests/{contestId}
```

관리 액션:

- 콘테스트 생성
- 콘테스트 수정
- 콘테스트 삭제
- 제출 목록 확인
- 수상자 선정
- 상태 변경: `PRE_ACTIVE`, `ACTIVE`, `FINISHED`, `ANNOUNCED`

삭제 정책:

- 현재 앱은 `contests/{contestId}` 문서를 삭제한다.
- 새 프로젝트에서는 수상/참여 데이터 보존을 위해 `isDeleted=true` soft delete를 권장한다.

감사 로그 액션:

- `contest.create`
- `contest.update`
- `contest.delete`
- `contest.select_winner`
- `contest.status_change`

## 카드 DB 관리

카드 DB는 관리자와 사용자 요청이 섞인 운영 도메인이다.

대표 경로:

```text
cards/{catalogId}/cardProducts/{cardId}
cards/{catalogId}/cardRequests/{requestId}
cards/{catalogId}/cardProducts/{cardId}/revisions/{revisionId}
```

관리 액션:

- 카드 상품 생성/수정
- 대표 이미지 업로드
- revision 생성
- 요청 카드 import
- 요청 카드 reject
- revision rollback

권장:

- 카드 import/reject/rollback은 반드시 callable function으로 처리한다.
- `roles`가 `admin` 또는 `owner`인지 서버에서 검증한다.
- `sourceType: "admin"`, `reviewedByUid`, `reviewedAt`, `importRunId` 등을 남긴다.
- 감사 로그에는 변경 전/후 주요 필드와 요청 ID를 기록한다.

## 상품권 특가 URL 관리

대표 경로:

```text
giftcardDealSources/{sourceId}
giftcardDealSourceRequests/{requestId}
giftcardDeals/{dealId}
giftcardDeals/{dealId}/priceHistory/{historyId}
users/{uid}/giftcardDealAlerts/{alertId}
```

`giftcardDealSources/{sourceId}` 필드:

| 필드 | 설명 |
| --- | --- |
| `url` | 원본 URL |
| `normalizedUrl` | 중복 방지용 정규화 URL |
| `merchantId` / `merchantName` | 판매처 |
| `brandId` / `brandName` | 상품권 브랜드 |
| `denominationKRW` | 권종 |
| `faceValueKRW` | 액면가 |
| `displayName` | 표시명 |
| `enabled` | 수집 활성 여부 |
| `memo` | 운영 메모 |
| `lastCrawlStatus` | 최근 수집 상태 |
| `lastCrawlError` | 최근 수집 오류 |
| `lastPriceKRW` | 최근 가격 |
| `lastDiscountRate` | 최근 할인율 |
| `createdByUid` / `updatedByUid` | 운영자 |

URL 요청 승인:

```text
read giftcardDealSourceRequests/{requestId}
set giftcardDealSources/{sourceId}
merge giftcardDealSourceRequests/{requestId} {
  status: approved,
  sourceId,
  reviewedByUid,
  reviewedAt,
  updatedAt
}
create admin/audit_logs
```

URL 요청 반려:

```text
merge giftcardDealSourceRequests/{requestId} {
  status: rejected,
  reviewNote,
  reviewedByUid,
  reviewedAt,
  updatedAt
}
create admin/audit_logs
```

## 통계 대시보드

현재 앱 기준 집계 소스:

| 지표 | 쿼리 |
| --- | --- |
| 전체 사용자 | `users.count()` |
| 이용금지 사용자 | `users where isBanned == true count()` |
| 전체 게시글 | `collectionGroup("posts")` |
| 숨김 게시글 | `collectionGroup("posts")` 결과 중 `isHidden == true` |
| 삭제 게시글 | `collectionGroup("posts")` 결과 중 `isDeleted == true` |
| 게시글 신고 | `reports/posts/posts.count()` |
| 댓글 신고 | `reports/comments/comments.count()` |
| 채팅 신고 | `reports/chat_messages/messages.count()` |
| 콘테스트 | `contests.count()` |
| 카드 상품 | `cards/{catalogId}/cardProducts.count()` |

기간별 통계:

- 기준 기간: 최근 7일, 30일, 90일
- 사용자: `createdAt >= start`
- 게시글: `createdAt >= start`
- 신고: `reportedAt >= start`
- 게시판 순위: 기간 내 게시글의 `boardId`별 post/like/view 합산

새 프로젝트 권장:

- 작은 규모에서는 관리자 화면에서 직접 집계한다.
- 규모가 커지면 `admin/daily_stats/{yyyyMMdd}`에 Cloud Scheduler로 사전 집계한다.
- 대시보드는 사전 집계 문서만 읽는다.

## 보안 규칙 원칙

관리자 UI는 편의 장치일 뿐이다. Rules 또는 서버 검증이 실제 보안 경계다.

- `users/{uid}.roles`는 owner 또는 서버만 수정할 수 있다.
- `users/{uid}.isBanned`는 관리자만 수정할 수 있다.
- `users/{uid}.peanutCount` 직접 수정은 서버 전용으로 제한한다.
- `users/{uid}/peanut_history`의 `admin_gift` 타입은 서버 또는 관리자만 생성한다.
- `reports/*` 전역 큐는 관리자만 읽고 수정한다.
- 사용자는 자기 `users/{uid}/reports`만 읽을 수 있다.
- 원본 하위 reports는 신고자 본인과 관리자만 읽을 수 있다.
- `admin/*` 전체는 관리자만 읽고 쓴다.
- `bottom_sheet_ads`, `contests`, `giftcardDealSources`, 카드 DB 운영 컬렉션의 쓰기는 관리자만 허용한다.
- 게시글/댓글 숨김, 삭제, 복구는 관리자만 허용한다.
- 감사 로그는 생성 후 수정/삭제하지 못하게 한다.

권장 callable functions:

| 함수 | 역할 |
| --- | --- |
| `adminSetReportStatus` | 신고 상태 변경 |
| `adminHideReportTarget` | 신고 대상 숨김 |
| `adminSetUserBan` | 이용금지/해제 |
| `adminAdjustPeanuts` | 땅콩 지급/회수 |
| `adminSetPostHidden` | 게시글 숨김/해제 |
| `adminSetPostDeleted` | 게시글 삭제/복구 |
| `adminSaveAd` | 광고 생성/수정 |
| `adminDeleteAd` | 광고 삭제와 Storage 정리 |
| `adminApproveSourceRequest` | 상품권 URL 요청 승인 |
| `adminRejectSourceRequest` | 상품권 URL 요청 반려 |

## 인덱스

| 범위 | 조건 | 정렬 |
| --- | --- | --- |
| `users` | 없음 | `lastLoginAt desc` |
| `users` | `isBanned == true` | 없음 |
| collection group `posts` | 없음 | `createdAt desc` |
| collection group `posts` | `isDeleted == false` | `likesCount desc` |
| collection group `comments` | 없음 | `createdAt desc` |
| `reports/posts/posts` | `status == pending` | `reportedAt desc` |
| `reports/comments/comments` | `status == pending` | `reportedAt desc` |
| `reports/chat_messages/messages` | `status == pending` | `reportedAt desc` |
| `users/{uid}/peanut_history` | `type == value` | `createdAt desc` |
| `bottom_sheet_ads` | 없음 | `priority asc` |
| `contests` | 없음 | `createdAt desc` |
| `giftcardDealSources` | 없음 | `updatedAt desc` |
| `giftcardDealSourceRequests` | `status == pending` | `createdAt desc` |
| `giftcardDeals` | 없음 | `discountRate desc` |

## 새 프로젝트 구축 체크리스트

1. `users/{uid}` 기본값에 `roles: ["user"]`, `isBanned: false`를 넣는다.
2. 첫 운영자에게 `roles: ["user", "admin"]` 또는 `["user", "owner"]`를 수동 seed한다.
3. 설정/프로필 화면에 관리자 진입 버튼을 붙인다.
4. 관리자 허브 화면을 만들고 최소 메뉴로 신고 관리, 사용자 관리, 게시글 관리, 운영 로그를 둔다.
5. 신고 접수 시 원본 하위 reports, 전역 reports, 사용자 reports를 함께 생성한다.
6. 관리자 신고 처리 액션은 세 신고 문서 사본을 모두 merge한다.
7. 숨김/삭제/이용금지/땅콩 지급은 감사 로그를 남긴다.
8. `isBanned` 사용자는 게시글 작성, 댓글 작성, 채팅 전송, FAB 노출을 막는다.
9. `admin/audit_logs`는 관리자만 읽고, 서버만 생성하게 제한한다.
10. 광고/콘테스트/카드/상품권 URL 관리는 도메인별로 관리자 메뉴에 추가한다.
11. Firestore Rules 또는 callable functions로 관리자 쓰기를 서버에서 재검증한다.
12. 대시보드가 느려지면 `admin/daily_stats/{yyyyMMdd}` 사전 집계로 전환한다.

## 최소 구현 순서

1. 권한 모델과 관리자 진입 버튼
2. 신고 접수/신고 관리
3. 게시글/댓글/채팅 숨김 처리
4. 사용자 이용금지
5. 운영 감사 로그
6. 땅콩 지급/회수
7. 게시글 삭제/복구
8. 광고/콘테스트 관리
9. 카드 DB/상품권 URL 관리
10. 통계 대시보드와 사전 집계

