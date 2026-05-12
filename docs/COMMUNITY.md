# Firestore Community Architecture

최종 업데이트: 2026-05-10

이 문서는 `db_schema.md`를 기준으로 커뮤니티 기능을 Firestore에 재구축할 수 있도록 정리한 아키텍처 가이드다. 목표는 앱, 웹, SSR, 공유 URL까지 같은 데이터 모델을 바라보게 만드는 것이다.

## 설계 원칙

- 게시글 원본은 `posts/{yyyyMMdd}/posts/{postId}`에 저장한다.
- `users/{uid}` 아래의 활동 서브컬렉션은 원본을 빠르게 찾기 위한 얇은 미러 인덱스다.
- 앱 내부 이동은 `dateString + postId` 또는 `postPath`를 사용한다.
- 웹 공개 URL은 불변 공개 번호인 `postNumber`를 사용한다.
- 웹/SSR은 `post_numbers/{postNumber}` lookup 문서를 먼저 읽고 원본 게시글로 이동한다.
- 작성자 정보는 읽기 성능을 위해 게시글/댓글에 스냅샷으로 비정규화한다.
- 카운터는 `postsCount`, `commentCount`, `likesCount`, `reportsCount`처럼 문서 필드로 저장하고 batch, transaction, Cloud Functions로 보정한다.
- 삭제는 기본적으로 soft delete다. 원본을 지우기보다 `isDeleted`, `isHidden`, `hiddenByReport` 상태를 갱신한다.
- 본문 전체를 사용자 서브컬렉션에 복제하지 않는다. 목록/이동에 필요한 최소 필드만 둔다.

## 공개 식별자와 웹 조회

Firestore 내부 키와 웹 공개 식별자는 역할을 분리한다.

| 값 | 용도 | 예시 | 변경 가능 여부 |
| --- | --- | --- | --- |
| `dateString` | 날짜 파티션 문서 ID | `20250609` | 불변 |
| `postId` | Firestore 원본 게시글 문서 ID | `abc123` | 불변 |
| `postPath` | 원본 문서 경로 | `posts/20250609/posts/abc123` | 불변 |
| `postNumber` | 웹/SSR/공유 URL용 공개 번호 | `12345` | 불변 |

권장 URL:

```text
/community/posts/{postNumber}
```

웹 조회 흐름:

1. `post_numbers/{postNumber}`를 읽는다.
2. lookup 문서의 `postPath`, `dateString`, `postId`를 확인한다.
3. `posts/{dateString}/posts/{postId}` 원본을 읽는다.
4. `isDeleted`, `isHidden`, `readRestriction`을 검사한 뒤 렌더링한다.

`post_numbers/{postNumber}` 예시:

```json
{
  "postNumber": "12345",
  "postPath": "posts/20250609/posts/abc123",
  "dateString": "20250609",
  "postId": "abc123",
  "boardId": "deal",
  "title": "상테크 카드 추천",
  "authorUid": "user_abc",
  "isDeleted": false,
  "isHidden": false,
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

`postNumber` 할당 정책:

- 카운터 문서: `meta/postNumber`
- 필드: `number`
- 새 게시글 작성 시 transaction으로 `number + 1`을 할당한다.
- 할당된 번호는 문자열로 저장한다.
- 게시글 작성이 중간 실패해 번호 gap이 생기는 것은 허용한다.
- 한 번 발행된 `postNumber`는 수정하거나 재사용하지 않는다.

## 컬렉션 맵

| 경로 | 역할 |
| --- | --- |
| `users/{uid}` | 사용자 프로필, 등급, 포인트, 카운터 |
| `users/{uid}/my_posts/{postId}` | 내가 쓴 글 목록용 미러 인덱스 |
| `users/{uid}/my_comments/{commentId}` | 내가 쓴 댓글 목록용 미러 인덱스 |
| `users/{uid}/liked_posts/{postId}` | 내가 좋아요한 글 목록 |
| `users/{uid}/bookmarks/{postId}` | 내가 북마크한 글 목록 |
| `users/{uid}/following/{targetUid}` | 내가 팔로우한 사용자 |
| `users/{uid}/followers/{followerUid}` | 나를 팔로우한 사용자 |
| `users/{uid}/blocked/{blockedUid}` | 내가 차단한 사용자 |
| `users/{uid}/notifications/{notificationId}` | 사용자별 알림 히스토리 |
| `users/{uid}/reports/{reportId}` | 내가 제출한 신고 내역 |
| `posts/{yyyyMMdd}/posts/{postId}` | 게시글 원본 |
| `posts/{yyyyMMdd}/posts/{postId}/comments/{commentId}` | 댓글/답글 원본 |
| `posts/{yyyyMMdd}/posts/{postId}/likes/{uid}` | 게시글 좋아요 여부 |
| `posts/{yyyyMMdd}/posts/{postId}/reports/{uid}` | 게시글 신고 중복 방지와 상세 |
| `posts/{yyyyMMdd}/posts/{postId}/comments/{commentId}/likes/{uid}` | 댓글 좋아요 여부 |
| `posts/{yyyyMMdd}/posts/{postId}/comments/{commentId}/reports/{uid}` | 댓글 신고 중복 방지와 상세 |
| `post_numbers/{postNumber}` | 웹 공개 번호에서 원본 경로로 가는 lookup |
| `boards/{boardId}` | Firestore 기준 게시판 정의 |
| `reports/posts/posts/{reportId}` | 운영자용 게시글 신고 큐 |
| `reports/comments/comments/{reportId}` | 운영자용 댓글 신고 큐 |
| `meta/postNumber` | 게시글 공개 번호 카운터 |
| `meta/bestPosts` | 베스트 글 수동/자동 큐 |
| `admin/*` | 운영자 전용 백업, 설정, 로그 |

## 사용자 문서

`users/{uid}`는 인증 사용자와 커뮤니티 활동 상태를 연결한다. 현재 코드 기준 공식 게시글 수 필드는 `postsCount`다. `postCount`는 레거시 이름으로 보고 새 프로젝트에서는 쓰지 않는다.

권장 필드:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `uid` | string | Firebase Auth UID |
| `email` | string | 이메일 |
| `displayName` | string | 닉네임 |
| `photoURL` | string | 프로필 이미지 |
| `joinedAt` | timestamp | 가입 시각 |
| `createdAt` | timestamp | 사용자 문서 생성 시각 |
| `lastLoginAt` | timestamp | 마지막 로그인 시각 |
| `postsCount` | number | 작성한 게시글 수 |
| `commentCount` | number | 작성한 댓글 수 |
| `likesReceived` | number | 받은 좋아요 수 |
| `likesCount` | number | 누른 좋아요 수 |
| `grade` | string | 등급 |
| `gradeLevel` | number | 등급 내 레벨 |
| `displayGrade` | string | UI 표시 등급 |
| `peanutCount` | number | 커뮤니티 포인트 |
| `peanutCountLimit` | number | 포인트 제한 |
| `fcmToken` | string | 푸시 토큰 |
| `followingCount` | number | 팔로잉 수 |
| `followerCount` | number | 팔로워 수 |
| `roles` | array | `user`, `admin` 등 권한 |
| `isBanned` | boolean | 차단 여부 |

`users/{uid}/my_posts/{postId}`:

```json
{
  "postPath": "posts/20250609/posts/abc123",
  "postNumber": "12345",
  "dateString": "20250609",
  "postId": "abc123",
  "title": "상테크 카드 추천",
  "boardId": "deal",
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

`users/{uid}/my_comments/{commentId}`:

```json
{
  "commentPath": "posts/20250609/posts/abc123/comments/cmt789",
  "postPath": "posts/20250609/posts/abc123",
  "postNumber": "12345",
  "dateString": "20250609",
  "postId": "abc123",
  "commentId": "cmt789",
  "contentHtml": "<p>정보 감사합니다!</p>",
  "contentType": "html",
  "attachments": [],
  "createdAt": "serverTimestamp"
}
```

`users/{uid}/liked_posts/{postId}`:

```json
{
  "postPath": "posts/20250609/posts/abc123",
  "postNumber": "12345",
  "dateString": "20250609",
  "postId": "abc123",
  "title": "상테크 카드 추천",
  "likedAt": "serverTimestamp"
}
```

`users/{uid}/bookmarks/{postId}`:

```json
{
  "postPath": "posts/20250609/posts/abc123",
  "postNumber": "12345",
  "dateString": "20250609",
  "postId": "abc123",
  "title": "상테크 카드 추천",
  "boardId": "deal",
  "bookmarkedAt": "serverTimestamp"
}
```

`users/{uid}/blocked/{blockedUid}`:

```json
{
  "displayName": "차단한 유저 닉네임",
  "photoURL": "https://example.com/profile.png",
  "blockedAt": "serverTimestamp"
}
```

## 게시글 원본

경로:

```text
posts/{yyyyMMdd}/posts/{postId}
```

`yyyyMMdd`는 서비스 기준 시간대로 만든 날짜 파티션이다. 한국 서비스라면 `Asia/Seoul` 기준으로 고정한다. 클라이언트가 생성하더라도 저장된 `dateString`을 이후 모든 이동의 기준으로 사용한다.

게시글 필드:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `postId` | string | 문서 ID |
| `postNumber` | string | 웹 공개 번호 |
| `boardId` | string | 게시판 ID |
| `title` | string | 제목 |
| `contentHtml` | string | HTML 본문 |
| `author` | map | 작성자 스냅샷 |
| `viewsCount` | number | 조회수 |
| `likesCount` | number | 좋아요 수 |
| `commentCount` | number | 댓글 수 |
| `reportsCount` | number | 신고 수 |
| `readRestriction` | map | 읽기 제한 |
| `isDeleted` | boolean | 삭제 여부 |
| `isHidden` | boolean | 운영 숨김 여부 |
| `hiddenByReport` | boolean | 신고 누적 자동 숨김 여부 |
| `createdAt` | timestamp | 작성 시각 |
| `updatedAt` | timestamp | 수정 시각 |

예시:

```json
{
  "postId": "abc123",
  "postNumber": "12345",
  "boardId": "deal",
  "title": "상테크 카드 추천",
  "contentHtml": "<p>본문</p>",
  "author": {
    "uid": "user_abc",
    "displayName": "vory!",
    "photoURL": "https://example.com/profile.png",
    "displayGrade": "이코노미 Lv.1",
    "currentSkyEffect": ""
  },
  "viewsCount": 0,
  "likesCount": 0,
  "commentCount": 0,
  "reportsCount": 0,
  "readRestriction": {
    "enabled": false,
    "minRank": 0,
    "label": "전체 공개"
  },
  "isDeleted": false,
  "isHidden": false,
  "hiddenByReport": false,
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

작성자 스냅샷은 목록 렌더링을 빠르게 하기 위한 비정규화 데이터다. 닉네임, 프로필 이미지, 등급, 스카이 이펙트가 바뀌면 사용자의 `my_posts`와 `my_comments`를 따라 원본 게시글/댓글을 갱신한다.

## 댓글 원본

경로:

```text
posts/{yyyyMMdd}/posts/{postId}/comments/{commentId}
```

댓글은 원댓글과 답글을 같은 컬렉션에 저장한다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `commentId` | string | 댓글 문서 ID |
| `uid` | string | 작성자 UID |
| `displayName` | string | 작성자 닉네임 스냅샷 |
| `profileImageUrl` | string | 작성자 프로필 이미지 스냅샷 |
| `displayGrade` | string | 작성자 등급 스냅샷 |
| `currentSkyEffect` | string | 작성자 이펙트 스냅샷 |
| `contentHtml` | string | HTML 댓글 본문 |
| `contentType` | string | `html` |
| `attachments` | array | 이미지 등 첨부 |
| `parentCommentId` | string | 답글이면 부모 댓글 ID, 원댓글이면 null |
| `depth` | number | 원댓글 0, 답글 1 |
| `replyToUserId` | string | 답글 대상 UID |
| `mentionedUsers` | array | 멘션된 UID 목록 |
| `hasMention` | boolean | 멘션 포함 여부 |
| `likesCount` | number | 댓글 좋아요 수 |
| `reportsCount` | number | 댓글 신고 수 |
| `isDeleted` | boolean | 삭제 여부 |
| `isHidden` | boolean | 숨김 여부 |
| `hiddenByReport` | boolean | 신고 누적 자동 숨김 여부 |
| `createdAt` | timestamp | 작성 시각 |
| `updatedAt` | timestamp | 수정 시각 |

예시:

```json
{
  "commentId": "cmt789",
  "uid": "user_def",
  "displayName": "마일러",
  "profileImageUrl": "https://example.com/profile.png",
  "displayGrade": "이코노미 Lv.2",
  "currentSkyEffect": "",
  "contentHtml": "<p>정보 감사합니다!</p>",
  "contentType": "html",
  "attachments": [],
  "parentCommentId": null,
  "depth": 0,
  "replyToUserId": null,
  "mentionedUsers": [],
  "hasMention": false,
  "likesCount": 0,
  "reportsCount": 0,
  "isDeleted": false,
  "isHidden": false,
  "hiddenByReport": false,
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

## 게시판 정의

공식 기준은 Firestore `boards/{boardId}`다.

```json
{
  "boardId": "deal",
  "name": "적립/카드 혜택",
  "group": "마일리지/혜택",
  "description": "상테크, 카드 추천, 이벤트 정보",
  "order": 2,
  "icon": "card_giftcard",
  "fabEnabled": true,
  "isActive": true,
  "writeRoles": ["user"],
  "readRestriction": {
    "enabled": false,
    "minRank": 0,
    "label": "전체 공개"
  },
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

기본 게시판:

| boardId | 이름 | 용도 |
| --- | --- | --- |
| `free` | 자유게시판 | 잡담, 후기, 가벼운 질문 |
| `deal` | 적립/카드 혜택 | 상테크, 카드, 이벤트 |
| `hot_deal` | 핫딜 | 항공권, 호텔, 여행 핫딜 |
| `question` | 마일리지 | 항공사 정책, 발권 문의 |
| `seat_share` | 좌석 공유 | 좌석 오픈, 취소표 공유 |
| `review` | 항공 리뷰 | 라운지, 기내식, 좌석 후기 |
| `news` | 오늘의 뉴스 | 여행, 항공, 카드 뉴스 |
| `error_report` | 오류 신고 | 앱 오류 제보 |
| `suggestion` | 건의사항 | 개선 요청 |
| `notice` | 운영 공지사항 | 관리자 공지 |

현재 앱에는 Realtime Database `CATEGORIES`를 읽는 코드가 남아 있을 수 있다. 새 프로젝트에서는 `boards/{boardId}`를 단일 기준으로 잡고, 기존 앱 마이그레이션 시에만 RTDB 값을 Firestore로 복사한다.

## 쓰기 레시피

### 게시글 작성

반드시 transaction과 batch를 함께 사용한다.

1. `meta/postNumber`를 transaction으로 읽고 `number + 1`을 저장한다.
2. `postId`와 `dateString`을 만든다.
3. `posts/{dateString}/posts/{postId}` 원본 게시글을 만든다.
4. `post_numbers/{postNumber}` lookup 문서를 만든다.
5. `users/{uid}/my_posts/{postId}` 미러 문서를 만든다.
6. `users/{uid}.postsCount`를 증가시킨다.

Batch에 함께 들어가야 하는 쓰기:

```text
set posts/{dateString}/posts/{postId}
set post_numbers/{postNumber}
set users/{uid}/my_posts/{postId}
update users/{uid}.postsCount += 1
```

`my_posts`에는 목록과 이동에 필요한 최소 필드만 넣는다. `contentHtml`은 복제하지 않는다.

### 게시글 수정

수정 가능한 필드:

- `title`
- `contentHtml`
- `boardId`
- `readRestriction`
- `entityRefs`
- `updatedAt`

같이 갱신할 미러:

- `users/{uid}/my_posts/{postId}.title`
- `users/{uid}/my_posts/{postId}.boardId`
- `users/{uid}/my_posts/{postId}.updatedAt`
- `post_numbers/{postNumber}.title`
- `post_numbers/{postNumber}.boardId`
- `post_numbers/{postNumber}.updatedAt`

수정하면 안 되는 필드:

- `postId`
- `postNumber`
- `dateString`
- `postPath`
- `createdAt`

### 게시글 삭제

권장 정책:

1. 원본 게시글에 `isDeleted=true`, `updatedAt=serverTimestamp`를 저장한다.
2. `post_numbers/{postNumber}.isDeleted=true`를 저장한다.
3. `users/{uid}.postsCount`를 감소시킨다.
4. 작성자의 `my_posts/{postId}`는 서비스 UX에 따라 삭제하거나 `isDeleted=true`로 표시한다.
5. 운영 백업이 필요하면 `admin/deleted_posts/{postId}`에 스냅샷을 저장한다.

공개 URL은 삭제 후에도 lookup이 가능해야 한다. 웹은 lookup 결과가 `isDeleted=true`이면 삭제 안내 화면을 보여준다.

### 댓글 작성

1. `comments/{commentId}` 원본 댓글을 만든다.
2. `users/{uid}/my_comments/{commentId}` 미러 문서를 만든다.
3. `posts/{dateString}/posts/{postId}.commentCount`를 증가시킨다.
4. `users/{uid}.commentCount`를 증가시킨다.
5. 댓글/답글 알림은 Cloud Functions에서 처리한다.

Batch에 함께 들어가야 하는 쓰기:

```text
set posts/{dateString}/posts/{postId}/comments/{commentId}
set users/{uid}/my_comments/{commentId}
update posts/{dateString}/posts/{postId}.commentCount += 1
update users/{uid}.commentCount += 1
```

### 댓글 삭제

댓글도 soft delete를 기본으로 한다.

- `comments/{commentId}.isDeleted=true`
- `comments/{commentId}.contentHtml="<p>삭제된 댓글입니다.</p>"`
- `posts/{dateString}/posts/{postId}.commentCount -= 1`
- `users/{uid}/my_comments/{commentId}` 삭제 또는 `isDeleted=true`
- `users/{uid}.commentCount -= 1`

대댓글이 있는 원댓글은 원문만 삭제 표시하고 문서 자체는 유지한다.

### 게시글 좋아요

좋아요 추가:

```text
set posts/{dateString}/posts/{postId}/likes/{uid}
set users/{uid}/liked_posts/{postId}
update posts/{dateString}/posts/{postId}.likesCount += 1
update users/{uid}.likesCount += 1
```

좋아요 취소:

```text
delete posts/{dateString}/posts/{postId}/likes/{uid}
delete users/{uid}/liked_posts/{postId}
update posts/{dateString}/posts/{postId}.likesCount -= 1
update users/{uid}.likesCount -= 1
```

`likes/{uid}` 문서 ID를 UID로 고정하면 중복 좋아요를 자연스럽게 막을 수 있다.

### 댓글 좋아요

좋아요 추가:

```text
set posts/{dateString}/posts/{postId}/comments/{commentId}/likes/{uid}
update posts/{dateString}/posts/{postId}/comments/{commentId}.likesCount += 1
```

댓글 좋아요 목록이 마이페이지에 필요하지 않다면 사용자 미러는 만들지 않는다.

### 북마크

북마크는 사용자 개인 기능이므로 원본 게시글에는 카운터를 두지 않는 것을 기본으로 한다.

```text
set users/{uid}/bookmarks/{postId}
delete users/{uid}/bookmarks/{postId}
```

북마크 문서에는 `postPath`, `postNumber`, `dateString`, `postId`, `title`, `boardId`, `bookmarkedAt`을 저장한다.

### 신고

신고는 중복 방지, 운영자 큐, 사용자 신고 내역을 모두 만족해야 한다.

게시글 신고:

```text
set posts/{dateString}/posts/{postId}/reports/{reporterUid}
set reports/posts/posts/{reportId}
set users/{reporterUid}/reports/{reportId}
update posts/{dateString}/posts/{postId}.reportsCount += 1
```

댓글 신고:

```text
set posts/{dateString}/posts/{postId}/comments/{commentId}/reports/{reporterUid}
set reports/comments/comments/{reportId}
set users/{reporterUid}/reports/{reportId}
update posts/{dateString}/posts/{postId}/comments/{commentId}.reportsCount += 1
```

신고 사유 enum:

| 값 | 설명 |
| --- | --- |
| `abuse` | 욕설/비방 |
| `spam` | 도배/광고 |
| `sexual` | 음란/선정성 |
| `hate` | 혐오/차별 |
| `etc` | 기타 |

권장 자동 처리:

- 게시글 신고 5회 이상: `isHidden=true`, `hiddenByReport=true`
- 댓글 신고 6회 이상: `isHidden=true`, `hiddenByReport=true`
- 운영자 검토 후 `reports/*/{reportId}.status`를 `pending`, `reviewed`, `resolved`, `rejected` 중 하나로 갱신한다.

### 알림

알림은 Cloud Functions가 생성한다. 클라이언트가 직접 다른 사용자의 `notifications`에 쓰지 않게 한다.

트리거 예시:

| 트리거 | 알림 타입 | 수신자 |
| --- | --- | --- |
| `posts/{date}/posts/{postId}/likes/{uid}` onCreate | `post_like` | 게시글 작성자 |
| `posts/{date}/posts/{postId}/comments/{commentId}` onCreate | `post_comment` | 게시글 작성자 |
| `comments/{commentId}` onCreate with `parentCommentId` | `comment_reply` | 부모 댓글 작성자 |
| `comments/{commentId}/likes/{uid}` onCreate | `comment_like` | 댓글 작성자 |
| `users/{uid}/followers/{followerUid}` onCreate | `follow` | 팔로우 받은 사용자 |

`users/{receiverUid}/notifications/{notificationId}`:

```json
{
  "type": "post_comment",
  "title": "댓글 알림",
  "body": "마일러님이 게시글에 댓글을 달았습니다.",
  "postId": "abc123",
  "postNumber": "12345",
  "date": "20250609",
  "boardId": "deal",
  "boardName": "적립/카드 혜택",
  "commentId": "cmt789",
  "authorUid": "user_def",
  "authorName": "마일러",
  "path": "/community/posts/12345",
  "isRead": false,
  "createdAt": "serverTimestamp"
}
```

권장 보관 정책:

- 최대 50개 보관
- 7일 후 삭제
- `isRead=false` 개수는 클라이언트에서 query하거나 별도 카운터로 유지한다.

### 팔로우와 차단

팔로우 추가:

```text
set users/{myUid}/following/{targetUid}
set users/{targetUid}/followers/{myUid}
update users/{myUid}.followingCount += 1
update users/{targetUid}.followerCount += 1
```

팔로우 취소:

```text
delete users/{myUid}/following/{targetUid}
delete users/{targetUid}/followers/{myUid}
update users/{myUid}.followingCount -= 1
update users/{targetUid}.followerCount -= 1
```

차단은 `users/{myUid}/blocked/{blockedUid}`에만 저장한다. 피드 조회 시 차단한 작성자의 글을 필터링한다. Firestore `whereNotIn`은 최대 10개 제한이 있으므로, 차단 수를 정책적으로 제한하거나 클라이언트 필터링을 병행한다.

## 읽기 패턴

커뮤니티 전체 피드:

```text
collectionGroup("posts")
where isDeleted == false
orderBy createdAt desc
limit 20
```

게시판별 피드:

```text
collectionGroup("posts")
where boardId == selectedBoardId
where isDeleted == false
orderBy createdAt desc
limit 20
```

인기 글:

```text
collectionGroup("posts")
where isDeleted == false
orderBy likesCount desc
limit 10
```

마이페이지 내가 쓴 글:

```text
users/{uid}/my_posts
orderBy createdAt desc
limit 20
```

마이페이지 내가 쓴 댓글:

```text
users/{uid}/my_comments
orderBy createdAt desc
limit 20
```

웹 상세:

```text
post_numbers/{postNumber}
-> posts/{dateString}/posts/{postId}
```

앱 상세:

```text
posts/{dateString}/posts/{postId}
```

검색:

- 간단 검색은 최근 N개 게시글을 가져와 클라이언트에서 제목/본문을 필터링할 수 있다.
- 운영 규모가 커지면 Algolia, Typesense, Meilisearch, Elasticsearch 같은 외부 검색 인덱스를 둔다.
- Firestore 단독으로 본문 contains 검색을 구현하려고 하지 않는다.

## 필요한 인덱스

Firestore 콘솔에서 에러 링크가 나오면 그대로 생성하되, 새 프로젝트에서는 아래 인덱스를 먼저 준비한다.

| 범위 | 조건 | 정렬 |
| --- | --- | --- |
| collection group `posts` | `isDeleted == false` | `createdAt desc` |
| collection group `posts` | `boardId == value`, `isDeleted == false` | `createdAt desc` |
| collection group `posts` | `isDeleted == false` | `likesCount desc` |
| collection group `posts` | `postId in [...]`, `isDeleted == false` | 없음 |
| collection group `comments` | `uid == value` | `createdAt desc` |
| `reports/posts/posts` | `status == pending` | `reportedAt desc` |
| `reports/comments/comments` | `status == pending` | `reportedAt desc` |

`postNumber` 조회는 `post_numbers/{postNumber}` 직접 읽기를 사용하므로 collectionGroup 인덱스가 필요 없다.

## 보안 규칙 원칙

실제 rules 파일은 프로젝트별로 작성하되, 다음 원칙을 지킨다.

- 로그인 사용자는 공개 게시글을 읽을 수 있다.
- `isDeleted=true` 게시글은 일반 사용자가 읽지 못하게 하거나, 읽더라도 삭제 안내에 필요한 최소 필드만 허용한다.
- 게시글 생성 시 `request.auth.uid == request.resource.data.author.uid`를 확인한다.
- 일반 사용자는 자신의 글만 제한된 필드로 수정할 수 있다.
- `postId`, `postNumber`, `createdAt`, `author.uid`는 생성 후 일반 사용자가 수정하지 못한다.
- 카운터 필드는 가능하면 Cloud Functions 또는 신뢰된 서버에서만 수정한다.
- `likes/{uid}`와 `reports/{uid}` 문서 ID는 반드시 로그인 UID와 같아야 한다.
- `users/{uid}/my_posts`, `my_comments`, `liked_posts`, `bookmarks`는 해당 사용자만 읽고 쓴다.
- `post_numbers/{postNumber}`는 읽기는 허용하되 쓰기는 서버 또는 관리자만 허용한다.
- `boards/{boardId}`는 읽기 공개, 쓰기 관리자 전용으로 둔다.
- `reports/*` 전역 큐와 `admin/*`은 관리자만 읽고 쓴다.
- `notifications`는 수신자만 읽고, 쓰기는 서버만 허용한다.

## Cloud Functions 권장 책임

클라이언트 batch만으로도 기본 기능은 가능하지만, 운영 안정성을 위해 서버가 맡는 영역을 분리한다.

| 책임 | 이유 |
| --- | --- |
| 알림 생성과 FCM 발송 | 타 사용자 문서 쓰기를 클라이언트에 열지 않기 위해 |
| 신고 임계값 자동 숨김 | 운영 정책을 중앙화하기 위해 |
| 카운터 재계산/보정 | batch 실패, 레거시 데이터 불일치 보정 |
| `post_numbers` 생성 검증 | 웹 공개 URL 무결성 보장 |
| 베스트 글 산정 | 클라이언트 조작 방지 |
| 알림 오래된 문서 정리 | 비용과 성능 관리 |
| 작성자 스냅샷 대량 갱신 | 프로필 변경 시 대량 업데이트 안정화 |

## 운영 정책

카운터:

- 클라이언트는 즉시 UI 반영을 위해 local state를 갱신할 수 있다.
- Firestore 카운터는 batch 또는 transaction으로 갱신한다.
- 주기적으로 원본 서브컬렉션 개수와 카운터를 비교하는 보정 작업을 둔다.

날짜 파티션:

- `posts/{yyyyMMdd}`는 게시글 수가 커져도 일자별로 문서가 분산되는 장점이 있다.
- collectionGroup query를 기본 조회 방식으로 사용한다.
- 앱/웹 라우팅에는 저장된 `dateString`을 사용하고, 현재 날짜로 재계산하지 않는다.

이미지/첨부:

- 게시글 이미지 Storage 경로는 `posts/{dateString}/posts/{postId}/images/...`를 권장한다.
- 댓글 이미지 Storage 경로는 `posts/{dateString}/posts/{postId}/comments/{commentId}/images/...`를 권장한다.
- Firestore에는 download URL, type, filename만 저장한다.

비정규화:

- `author`와 댓글 작성자 스냅샷은 목록 렌더링 성능을 위한 복제 데이터다.
- 사용자 원본 프로필과 언제든 불일치할 수 있으므로 프로필 변경 시 후속 갱신 작업을 둔다.
- 미러 문서에는 경로와 목록 표시 필드만 둔다.

레거시 주의:

- `postCount`가 남아 있으면 `postsCount`로 마이그레이션한다.
- 댓글 프로필 이미지 필드는 현재 앱에서 `profileImageUrl`을 사용한다. 사용자 문서의 원본 필드는 `photoURL`이다.
- 기존 앱에 RTDB `CATEGORIES`가 남아 있으면 Firestore `boards/{boardId}`로 옮긴 뒤 단일 기준으로 관리한다.

## 새 프로젝트 구축 체크리스트

1. Firebase Auth를 설정하고 로그인 성공 시 `users/{uid}`를 생성한다.
2. `boards/{boardId}` 기본 게시판 문서를 seed한다.
3. `meta/postNumber`에 `{ "number": 0 }`을 생성한다.
4. 게시글 작성 batch에 원본 post, `post_numbers`, `my_posts`, `postsCount` 증가를 함께 넣는다.
5. 댓글 작성 batch에 원본 comment, `my_comments`, post/user 카운터 증가를 함께 넣는다.
6. 좋아요는 원본 `likes/{uid}`와 사용자 `liked_posts/{postId}`를 함께 갱신한다.
7. 북마크는 사용자 `bookmarks/{postId}`만 갱신한다.
8. 신고는 원본 reports, 전역 reports, 사용자 reports를 함께 기록한다.
9. Cloud Functions로 알림, 신고 자동 숨김, 카운터 보정, 오래된 알림 삭제를 구현한다.
10. collectionGroup query용 composite index를 준비한다.
11. 보안 규칙에서 공개 번호 lookup은 읽기 허용, 쓰기는 서버 전용으로 제한한다.
12. 웹 상세 페이지는 `postNumber -> post_numbers -> postPath` 흐름만 사용한다.

## 최소 구현 순서

1. 사용자 문서와 게시판 문서를 만든다.
2. 게시글 작성과 웹 lookup을 먼저 완성한다.
3. 피드 목록과 상세 화면을 붙인다.
4. 댓글과 좋아요를 붙인다.
5. 마이페이지 활동 인덱스를 붙인다.
6. 신고와 관리자 큐를 붙인다.
7. 알림과 FCM을 붙인다.
8. 검색과 베스트 글은 마지막에 고도화한다.

