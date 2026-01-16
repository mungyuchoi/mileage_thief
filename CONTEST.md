# 콘테스트 시스템 Firestore DB 설계

최종 업데이트: 2025-01-09
기능 범위: 콘테스트 생성, 참여, 심사, 시상, 통계 관리

---

## :clipboard: 목차

1. [시스템 개요](#시스템-개요)
2. [데이터 구조 설계](#데이터-구조-설계)
3. [콘테스트 규칙](#콘테스트-규칙)
4. [운영자 관리](#운영자-관리)
5. [최적화 전략](#최적화-전략)

---

## :dart: 시스템 개요

콘테스트는 기존 게시글과 독립적으로 관리되며, 참여자들이 콘테스트 주제에 맞는 게시글을 작성하여 제출하는 구조입니다.

### 주요 특징
- **독립적인 컬렉션**: `contests/` 경로로 게시글과 분리 관리
- **게시글 연동**: 참여자는 일반 게시글을 작성하고 콘테스트에 연결
- **단계별 진행**: 제출 기간 → 투표 기간 → 심사 → 시상 발표
- **사용자 기록**: `users/{uid}/contests/` 서브컬렉션으로 참여 이력 관리

---

## :file_folder: 데이터 구조 설계

### :file_folder: contests/{contestId}

**콘테스트 메타 정보 및 설정**

#### :arrow_forward: 문서 필드

| 필드명                | 타입     | 설명 |
|-----------------------|----------|------|
| contestId             | string   | 문서 ID (고유 식별자) |
| title                 | string   | 콘테스트 제목 |
| description           | string   | 콘테스트 설명 (HTML 가능) |
| status                | string   | 상태: `PRE_ACTIVE`, `ACTIVE`, `FINISHED`, `ANNOUNCED` |
| postingDateStart      | timestamp| 제출 시작일시 |
| postingDateEnd        | timestamp| 제출 종료일시 |
| participantCount      | number   | 참여자 수 (자동 계산) |
| createdAt             | timestamp| 생성 시각 |
| updatedAt             | timestamp| 수정 시각 |

#### :clipboard: 예시 문서

```json
{
  "contestId": "contest_20250109_01",
  "title": "2025년 상반기 최고의 상테크 꿀팁 콘테스트",
  "description": "<p>여러분의 상테크 노하우를 공유해주세요!</p>",
  "status": "ACTIVE",
  "postingDateStart": "2025-01-09T00:00:00Z",
  "postingDateEnd": "2025-01-31T23:59:59Z",
  "participantCount": 0,
  "createdAt": "2025-01-08T10:00:00Z",
  "updatedAt": "2025-01-08T10:00:00Z"
}
```

### :open_file_folder: 서브컬렉션

#### :arrow_forward: submissions/{submissionId}

참여자가 제출한 게시글 정보

```json
{
  "submissionId": "sub_abc123",
  "uid": "user_abc",
  "displayName": "vory!",
  "photoURL": "https://...",
  "title": "내 상테크 노하우 공유합니다!",
  "contentHtml": "<p>상테크 노하우를 공유합니다!</p><img src=\"https://storage.../contests/sub_abc123/image1.jpg\" />",
  "likesCount": 42,
  "viewsCount": 150,
  "commentCount": 8,
  "submittedAt": "2025-01-15T14:30:00Z"
}
```

**필드 설명:**
- `submissionId`: 제출 고유 ID
- `uid`: 작성자 UID
- `displayName`: 작성자 닉네임
- `photoURL`: 작성자 프로필 이미지 URL
- `title`: 게시글 제목
- `contentHtml`: 게시글 본문 (HTML 형식)
- `likesCount`: 좋아요 수
- `viewsCount`: 조회수
- `commentCount`: 댓글 수
- `submittedAt`: 제출 시각

**이미지 업로드 방식:**
- 이미지는 Firebase Storage에 업로드
- 업로드 후 다운로드 URL을 받아서 `contentHtml`의 `<img>` 태그에 삽입
- 예: `<img src="https://storage.googleapis.com/.../contests/{contestId}/submissions/{submissionId}/image1.jpg" />`

#### :arrow_forward: winners/{rank}

수상자 정보 (1등, 2등, 3등 등)

```json
{
  "rank": 1,
  "submissionId": "sub_abc123"
}
```

---

## :bust_in_silhouette: users/{uid} 서브컬렉션

### :open_file_folder: contests/{contestId}

사용자가 참여한 콘테스트 기록

```json
{
  "contestId": "contest_20250109_01",
  "contestTitle": "2025년 상반기 최고의 상테크 꿀팁 콘테스트",
  "submissionId": "sub_abc123",
  "submissionTitle": "내 상테크 노하우 공유합니다!",
  "status": "submitted",
  "participatedAt": "2025-01-15T14:30:00Z",
  "updatedAt": "2025-01-15T14:30:00Z"
}
```

**필드 설명:**
- `contestId`: 참여한 콘테스트 ID
- `contestTitle`: 콘테스트 제목 (비정규화, 읽기 최적화)
- `submissionId`: 제출 ID
- `submissionTitle`: 제출한 게시글 제목 (비정규화, 읽기 최적화)
- `status`: 상태 (`draft`, `submitted`, `disqualified`, `winner`)
- `participatedAt`: 참여 시각
- `updatedAt`: 수정 시각

---

## :video_game: 콘테스트 규칙

### :clipboard: 참여 자격

1. **회원 가입 필수**: Firebase Auth로 로그인한 사용자
2. **등급 제한 없음**: 모든 등급 참여 가능 (옵션: 특정 등급 이상만 가능하도록 설정 가능)
3. **중복 참여**: 콘테스트당 1인 1작품 제한 (정책에 따라 변경 가능)

### :memo: 참여 방법

1. **콘테스트 확인**: `contests/{contestId}` 문서 조회
2. **게시글 작성**: 일반 게시글 작성과 동일한 프로세스
3. **자동 제출**: 게시글 생성 시 `contests/{contestId}/submissions/` 자동 생성
5. **사용자 기록**: `users/{uid}/contests/{contestId}` 자동 생성

### :alarm_clock: 진행 단계

#### 1. PRE_ACTIVE (시작 전)
- 콘테스트 정보 공개
- 참여 불가
- UI: "곧 시작됩니다" 표시

#### 2. ACTIVE (제출 기간)
- 게시글 제출 가능
- `postingDateStart` ~ `postingDateEnd` 기간
- UI: "참여하기" 버튼 활성화

#### 3. FINISHED (제출 종료)
- 제출 불가
- 심사 진행
- UI: "제출 마감" 표시

#### 4. ANNOUNCED (시상 발표)
- 수상자 발표
- UI: 수상자 목록 표시

### :trophy: 심사 기준

1. **주제 적합성**: 콘테스트 주제와의 관련성
2. **창의성**: 독창적인 내용
3. **완성도**: 내용의 깊이와 품질
4. **인기도**: 좋아요, 조회수, 댓글 수 (옵션)
5. **규칙 준수**: 콘테스트 규칙 위반 여부

### :no_entry_sign: 실격 사유

- 부적절한 내용 (욕설, 비방, 음란 등)
- 타인의 저작권 침해
- 규칙 위반
- 중복 제출
- 운영진 판단에 의한 실격

---

## :male-office-worker: 운영자 관리

### :clipboard: 운영자 권한

운영자 권한(`roles` 배열에 `"admin"` 포함)을 가진 사용자만 다음 기능을 사용할 수 있습니다.

### :mag: 참여 목록 조회

콘테스트 기간이 종료되면(`status`가 `FINISHED` 또는 `ANNOUNCED`), 운영자는 해당 콘테스트의 참여 목록을 조회할 수 있습니다.

**조회 경로:**
- `contests/{contestId}/submissions/` 서브컬렉션 조회
- 제출된 모든 게시글 목록 확인 가능

### :trophy: 수상자 선정 프로세스

#### 1. 게시글 상세 조회
- 운영자는 `contests/{contestId}/submissions/{submissionId}` 문서를 통해 제출된 게시글 정보 확인
- `contentHtml` 필드로 게시글 본문 확인

#### 2. 옵션 메뉴를 통한 순위 선정
- 각 게시글 상세 화면에서 옵션 메뉴 제공
- 운영자만 볼 수 있는 "1위 선정", "2위 선정", "3위 선정" 옵션 표시
- 순위 선정 시 `contests/{contestId}/winners/{rank}` 문서 생성

#### 3. Winners 문서 생성
```javascript
// 1위 선정 예시
await db.collection('contests').doc(contestId)
  .collection('winners').doc('1').set({
    rank: 1,
    submissionId: 'sub_abc123'
  });

// 2위 선정 예시
await db.collection('contests').doc(contestId)
  .collection('winners').doc('2').set({
    rank: 2,
    submissionId: 'sub_xyz789'
  });

// 3위 선정 예시
await db.collection('contests').doc(contestId)
  .collection('winners').doc('3').set({
    rank: 3,
    submissionId: 'sub_def456'
  });
```

### :bar_chart: 콘테스트 상태 관리

#### 기간 종료 처리
- `postingDateEnd` 시각이 지나면 `status`를 `FINISHED`로 변경
- UI에서 "종료됨" 표시

```javascript
// 콘테스트 종료 처리
await db.collection('contests').doc(contestId).update({
  status: 'FINISHED',
  updatedAt: FieldValue.serverTimestamp()
});
```

#### 수상자 발표
- 1, 2, 3위 선정 완료 후 `status`를 `ANNOUNCED`로 변경 (선택사항)
- 수상자 정보는 `winners/` 서브컬렉션에서 조회 가능

### :memo: 수상자 게시글 작성

1, 2, 3위 선정 후 운영자는 별도로 `posts/` 컬렉션에 수상자 발표 게시글을 작성할 수 있습니다.

**권장 구조:**
- 게시판: `notice` (운영 공지사항) 또는 별도 게시판
- 제목: "콘테스트 수상자 발표" 등
- 본문: 수상자 정보 및 수상작 소개
- 수상자 정보는 `contests/{contestId}/winners/` 서브컬렉션에서 조회하여 포함

### :warning: 주의사항

- **중복 선정 방지**: 이미 선정된 순위(1, 2, 3)는 다시 선정 불가
- **순위 변경**: 필요 시 기존 winners 문서 삭제 후 재선정 가능
- **권한 확인**: 운영자 권한 체크는 클라이언트 및 서버 양쪽에서 검증 필요

---

## :arrows_counterclockwise: 데이터 흐름

### 참여 프로세스

```
1. 사용자: 게시글 작성 (contestId 포함)
   ↓
2. Cloud Function: 게시글 생성 감지
   ↓
3. 자동 생성:
   - contests/{contestId}/submissions/{submissionId}
   - users/{uid}/contests/{contestId}
   - contests/{contestId} participantCount 증가
   ↓
4. 사용자: 마이페이지에서 참여 기록 확인
```

### 수상자 선정 프로세스

```
1. 콘테스트 기간 종료 (status: FINISHED)
   ↓
2. 운영자: contests/{contestId}/submissions/ 목록 조회
   ↓
3. 운영자: 각 게시글 상세 화면에서 옵션 메뉴 확인
   ↓
4. 운영자: "1위 선정", "2위 선정", "3위 선정" 선택
   ↓
5. 시스템: contests/{contestId}/winners/{rank} 문서 생성
   ↓
6. 운영자: posts/ 컬렉션에 수상자 발표 게시글 작성 (선택사항)
   ↓
7. 사용자: 수상자 발표 게시글 또는 winners 서브컬렉션에서 확인
```

---

## :bar_chart: 필수 파라미터 요약

### 콘테스트 생성 시 필수
- `title`: 제목
- `description`: 설명
- `postingDateStart`: 제출 시작일시
- `postingDateEnd`: 제출 종료일시
- `status`: 상태

### 자동 계산 필드
- `participantCount`: 참여자 수

---

## :end: 요약

이 구조로 다음 기능을 안정적으로 지원할 수 있습니다:

:white_check_mark: 콘테스트 생성 및 관리
:white_check_mark: 사용자 참여 및 제출
:white_check_mark: 심사 및 수상자 선정
:white_check_mark: 통계 및 분석
:white_check_mark: 사용자 참여 기록 관리
:white_check_mark: 게시글과의 연동
:white_check_mark: 운영자 관리 도구

**핵심 설계 원칙:**
- 독립적인 `contests/` 컬렉션으로 게시글과 분리
- 비정규화를 통한 읽기 성능 최적화
- 트랜잭션을 통한 데이터 일관성 보장
- Cloud Functions를 통한 자동화
- 운영자 전용 admin 컬렉션으로 관리 효율화