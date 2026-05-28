# 마일리지도둑 Firebase DB Schema

최종 업데이트: 2026-05-28

분석 기준:
- `lib/services/*`
- `lib/repository/mileage_repository.dart`
- `lib/models/*`, `lib/model/*`
- 서비스 밖에서 직접 Firestore를 쓰는 주요 화면 코드

주의:
- 이 문서는 현재 Flutter 코드가 읽고 쓰는 DB 구조를 기준으로 정리합니다.
- Cloud Functions가 생성하는 문서는 Flutter 모델이 읽는 필드 기준으로 적었습니다.
- Timestamp는 Firestore `Timestamp`, `serverTimestamp()`는 서버 시각입니다.
- `postsCount`가 현재 사용자 글 수 필드입니다. 예전 `postCount`는 마이그레이션에서 삭제 대상입니다.

---

## 1. 주요 저장소

| 저장소 | 용도 |
| --- | --- |
| Firestore | 커뮤니티, 사용자, 상품권, 카드 카탈로그, 특가, 레이더, 호텔, 마일고사, 채팅 |
| Realtime Database | 게시판 카테고리, 앱 버전, 레거시 마일리지 좌석 데이터 |
| Remote Config | 공지 팝업 설정 |
| Storage | 게시글/댓글/채팅/카드/광고 이미지 |

---

## 2. users/{uid}

사용자 기본 정보, 커뮤니티 레벨, 알림 설정, 상품권 계산기 개인 데이터의 루트 문서입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `uid` | string | Firebase Auth UID |
| `email` | string | 이메일 |
| `displayName` | string | 닉네임 |
| `photoURL` | string | 프로필 이미지 URL |
| `joinedAt` | timestamp | 가입 시각 |
| `createdAt` | timestamp | 사용자 문서 생성 시각 |
| `lastLoginAt` | timestamp | 최근 로그인 시각 |
| `lastUpdatedAt` | timestamp | 사용자 값 갱신 시각 |
| `fcmToken` | string | FCM 토큰 |
| `lastFcmUpdate` | timestamp | FCM 토큰 갱신 시각 |
| `postsCount` | number | 작성 글 수 |
| `commentCount` | number | 작성 댓글 수 |
| `likesReceived` | number | 받은 좋아요 수 |
| `likesCount` | number | 내가 누른 좋아요 수 |
| `grade` | string | `이코노미`, `비즈니스`, `퍼스트` 등 |
| `gradeLevel` | number | 등급 내 레벨 |
| `displayGrade` | string | 예: `이코노미 Lv.1` |
| `gradeUpdatedAt` | timestamp | 등급 갱신 시각 |
| `peanutCount` | number | 땅콩 보유량 |
| `peanutCountLimit` | number | 기본 땅콩 제한값 |
| `followingCount` | number | 팔로잉 수 |
| `followerCount` | number | 팔로워 수 |
| `photoURLChangeCount` | number | 프로필 이미지 변경 횟수 |
| `displayNameChangeCount` | number | 닉네임 변경 횟수 |
| `photoURLEnable` | boolean | 프로필 이미지 변경 가능 여부 |
| `displayNameEnable` | boolean | 닉네임 변경 가능 여부 |
| `ownedEffects` | array<string> | 구매한 스카이 이펙트 ID 목록 |
| `currentSkyEffect` | string/null | 착용 중인 이펙트 ID |
| `roles` | array/string/map | 기본은 `["user"]`, 관리자 판정에 사용 |
| `isBanned` | boolean | 이용 제한 여부 |
| `bannedAt` | timestamp | 차단 시각 |
| `banReleasedAt` | timestamp | 차단 해제 시각 |
| `hasGift` | boolean | 상품권 계산기 초기 설정 여부 |
| `ranking_agree` | boolean | 상품권 랭킹 동의 여부 |
| `notificationPreferences` | map | 알림 설정 |
| `notificationPreferencesUpdatedAt` | timestamp | 알림 설정 갱신 시각 |

`notificationPreferences` 기본 키:

| 키 | 설명 |
| --- | --- |
| `community_post_like` | 내 게시글 좋아요 |
| `community_post_comment` | 내 게시글 댓글 |
| `community_comment_reply` | 내 댓글 답글 |
| `community_comment_like` | 내 댓글 좋아요 |
| `radar_all` | 레이더 전체 알림 마스터 스위치 |
| `radar_mileage_seat` | 마일리지 좌석 레이더 |
| `radar_cancel_alert` | 취소표 레이더 |
| `radar_flight_deal` | 항공권 특가 레이더 |
| `radar_giftcard` | 상품권 특가 레이더 |
| `radar_benefit_news` | 혜택 뉴스 레이더 |

로컬 설정 호환을 위해 `post_like_notification`, `post_comment_notification`, `comment_reply_notification`, `comment_like_notification`, `radar_notification` 레거시 키를 읽어 새 키로 병합합니다.

### users/{uid}/my_posts/{postId}

내가 작성한 게시글 미러입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `postPath` | string | `posts/{yyyyMMdd}/posts/{postId}` |
| `title` | string | 게시글 제목 |
| `boardId` | string | 게시판 ID |
| `createdAt` | timestamp | 작성 시각 |
| `updatedAt` | timestamp | 수정 시각 |

### users/{uid}/my_comments/{commentId}

내가 작성한 커뮤니티 댓글 미러입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `commentPath` | string | 댓글 경로 |
| `postPath` | string | 게시글 경로 |
| `contentHtml` | string | 댓글 HTML |
| `contentType` | string | 현재 `html` |
| `attachments` | array<map> | 첨부 이미지 |
| `createdAt` | timestamp | 작성 시각 |

### users/{uid}/liked_posts/{postId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `postPath` | string | 게시글 경로 |
| `title` | string | 제목 스냅샷 |
| `likedAt` | timestamp | 좋아요 시각 |

### users/{uid}/bookmarks/{postId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `postPath` | string | 게시글 경로 |
| `title` | string | 제목 스냅샷 |
| `bookmarkedAt` | timestamp | 북마크 시각 |

### users/{uid}/following/{targetUid}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `followedAt` | timestamp | 팔로우 시각 |

### users/{uid}/followers/{followerUid}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `followedAt` | timestamp | 팔로우 받은 시각 |

### users/{uid}/blocked/{blockedUid}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `displayName` | string | 차단 대상 닉네임 |
| `photoURL` | string | 차단 대상 프로필 이미지 |
| `blockedAt` | timestamp | 차단 시각 |

정책상 차단 목록은 최대 10명 기준으로 사용합니다.

### users/{uid}/notifications/{notificationId}

커뮤니티 및 시스템 알림 히스토리입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `notificationId` | string | 알림 ID |
| `type` | string | `comment`, `like`, `mention`, `follow`, `system`, 또는 코드상 `post_like`, `post_comment`, `comment_reply`, `comment_like` |
| `title` | string | 제목 |
| `body` | string | 본문 |
| `data` | map | 딥링크 데이터 |
| `isRead` | boolean | 읽음 여부 |
| `receivedAt` | timestamp | 수신 시각 |
| `createdAt` | timestamp | 생성 시각 |

조회는 `createdAt desc limit 50`, 오래된 알림 정리는 `receivedAt < now - 7 days` 기준입니다.

### users/{uid}/peanut_history/{historyId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `type` | string | `post_create`, `comment_create`, `post_like`, `admin_gift`, `mock_exam_retry_purchase` 등 |
| `amount` | number | 증감 땅콩 |
| `postId`, `dateString`, `boardId`, `postTitle` | string | 커뮤니티 관련 히스토리 |
| `reason`, `adminName` | string | 운영자 선물 또는 차감 사유 |
| `createdAt` | timestamp | 기록 시각 |

### users/{uid}/reports/{reportId}

내 신고 내역 미러입니다. 전역 `reports/*` 문서와 같은 `reportId`, `reportPath`, `userReportPath`를 가집니다.

### users/{uid}/cards/{cardId}

사용자 카드 적립 규칙입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `name` | string | 카드명 또는 카드사명 |
| `creditPerMileKRW` | number | 신용카드 1마일당 원가 |
| `checkPerMileKRW` | number | 체크카드 1마일당 원가 |
| `targetSpendKRW` | number | 월 목표 실적 |
| `statementCycle` | string | 현재 `calendar_month` |
| `catalogCardId` | string | 카드 카탈로그 연결 ID |
| `memo` | string/null | 메모 |
| `updatedAt` | timestamp | 수정 시각 |

### users/{uid}/lots/{lotId}

상품권 구매 로트입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `faceValue` | number | 권당 액면가 |
| `buyDate` | timestamp | 구매일 |
| `payType` | string | `신용` 또는 `체크` |
| `buyUnit` | number | 권당 매입가 |
| `discount` | number | 매입 할인율 |
| `qty` | number | 수량 |
| `cardId` | string | `users/{uid}/cards/{cardId}` |
| `mileRuleUsedPerMileKRW` | number | 구매 당시 카드 마일 규칙 스냅샷 |
| `miles` | number | 예상 적립 마일 |
| `status` | string | `open` 또는 `sold` |
| `trade` | boolean | 판매 완료 처리 여부 |
| `giftcardId` | string | 상품권 브랜드 ID |
| `whereToBuyId` | string/null | 구매처 ID |
| `memo` | string | 메모 |
| `createdAt` | timestamp | 생성 시각 |
| `updatedAt` | timestamp | 수정 시각 |

### users/{uid}/sales/{saleId}

상품권 판매 기록입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `lotId` | string | 연결 구매 로트 |
| `sellDate` | timestamp | 판매일 |
| `sellUnit` | number | 권당 판매가 |
| `discount` | number | 판매 할인율 |
| `sellTotal` | number | 판매 총액 |
| `buyTotal` | number | 매입 총액 스냅샷 |
| `qty` | number | 판매 수량 |
| `mileRuleUsedPerMileKRW` | number | 마일 규칙 스냅샷 |
| `miles` | number | 계산 마일 |
| `profit` | number | `sellTotal - buyTotal` |
| `costPerMile` | number | `miles == 0 ? 0 : -profit / miles` |
| `branchId` | string | 판매 지점 ID |
| `createdAt` | timestamp | 생성 시각 |
| `updatedAt` | timestamp | 수정 시각 |

### users/{uid}/where_to_buy/{whereToBuyId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `name` | string | 구매처 이름 |
| `memo` | string/null | 메모 |
| `updatedAt` | timestamp | 수정 시각 |

### users/{uid}/gift_templates/{templateId}

상품권 구매 입력 템플릿입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `name` | string | 템플릿명 |
| `nameLower` | string | 검색/정렬용 소문자 이름 |
| `pinned` | boolean | 고정 여부 |
| `useCount` | number | 사용 횟수 |
| `lastUsedAt` | timestamp/null | 마지막 사용 시각 |
| `dateMode` | string | 현재 `manual` |
| `payload` | map | `giftcardId`, `cardId`, `whereToBuyId`, `payType`, `faceValue`, `qty`, `priceInputMode`, `buyUnit`, `discount`, `memo`, `buyDate` |
| `version` | number | 템플릿 버전 |
| `createdAt` | timestamp | 생성 시각 |
| `updatedAt` | timestamp | 수정 시각 |

### users/{uid}/giftcard_settlements/{settlementId}

상품권 판매 정산서입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `status` | string | `planned` 또는 `completed` |
| `tradeDirection` | string | 현재 `sell` |
| `branchId` | string/null | 지점 ID |
| `branchNameSnapshot` | string | 지점명 스냅샷 |
| `settlementDate` | timestamp | 정산일 |
| `expectedTotal` | number | 예상 입금액 |
| `actualDepositTotal` | number/null | 실제 입금액 |
| `difference` | number | 차액 |
| `totalQuantity` | number | 총 수량 |
| `lineItems` | array<map> | 상품권별 정산 행 |
| `recountChecked` | boolean | 재확인 여부 |
| `memo` | string | 메모 |
| `createdAt` | timestamp | 생성 시각 |
| `updatedAt` | timestamp | 수정 시각 |
| `completedAt` | timestamp/null | 완료 시각 |

`lineItems[]`: `giftcardId`, `giftcardNameSnapshot`, `faceValue`, `qty`, `sellUnit`, `sellRate`, `lineTotal`, `memo`.

### users/{uid}/cardTransactions/{transactionId}

카드 실적/마일 계산용 거래입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `cardId` | string | 사용자 카드 ID |
| `source` | string | `gift_lot`, `manual`, `mydata` |
| `occurredAt` | timestamp | 거래일 |
| `amountKRW` | number | 거래액 |
| `merchantName` | string | 가맹점 |
| `category` | string | 카테고리 |
| `status` | string | `posted`, `deleted`, `canceled` 등 |
| `linkedGiftLotId` | string | 상품권 lot 연결 |
| `rawSourceKey` | string | 원본 경로 또는 원본 ID |
| `performance` | map | 실적 인정 결과 |
| `reward` | map | 마일 적립 결과 |
| `needsReview` | boolean | 검토 필요 여부 |
| `createdAt` | timestamp | 생성 시각 |
| `updatedAt` | timestamp | 수정 시각 |

`performance`: `eligible`, `amountKRW`, `reasonCodes`, `overridden`.

`reward`: `eligible`, `miles`, `mileRuleUsedPerMileKRW`, `reasonCodes`, `overridden`.

### users/{uid}/cardOverrides/{overrideId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `cardId` | string | 카드 ID |
| `scope` | string | `transaction` 또는 `merchant` |
| `transactionId` | string | 거래 단위 override일 때 |
| `merchantName` | string | 가맹점 |
| `category` | string | 카테고리 |
| `performanceEligible` | boolean | 실적 인정 여부 |
| `rewardEligible` | boolean | 적립 인정 여부 |
| `mileRuleUsedPerMileKRW` | number | 적용 마일 규칙 |
| `applyToFuture` | boolean | 향후 거래 적용 여부 |
| `memo` | string | 메모 |
| `updatedAt` | timestamp | 수정 시각 |

### users/{uid}/pointBalances/{brandId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `category` | string | `airline`, `hotel`, `card` |
| `brandId` | string | 포인트 브랜드 ID |
| `brandName` | string | 표시명 |
| `pointLabel` | string | `마일`, `포인트` 등 |
| `assetPath` | string | 앱 내 아이콘 |
| `fallbackAssetPath` | string | 대체 아이콘 |
| `balance` | number | 보유량 |
| `isRepresentative` | boolean | 카테고리 대표 포인트 여부 |
| `sortOrder` | number | 정렬값 |
| `updatedAt` | timestamp | 수정 시각 |

### users/{uid}/marriottStays/{stayId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `id` | string | 문서 ID |
| `stayType` | string | `paid`, `points`, `freeNightAward` |
| `checkIn`, `checkOut` | timestamp | 체크인/체크아웃 |
| `nights` | number | 숙박 수 |
| `hotelName` | string | 호텔명 |
| `totalAmount`, `roomRate`, `taxAmount`, `serviceCharge` | number | 금액 |
| `earnedPoints` | number | 적립 포인트 |
| `returnRate` | number | 환급률 |
| `bookingNumber` | string | 예약번호 |
| `memo` | string | 메모 |
| `pointValueKrw` | number | 포인트 가치 |
| `exchangeRateKrwPerUsd` | number | USD/KRW 환율 |
| `eliteTierName` | string | 엘리트 등급명 |
| `eliteMultiplier` | number | 등급 보너스 배수 |
| `welcomePoints`, `promoPoints` | number | 웰컴/프로모션 포인트 |
| `createdAt`, `updatedAt` | timestamp | 생성/수정 시각 |

### users/{uid}/liked_hotels/{hotelId}

포인트 호텔 찜 미러입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `hotelId` | string | 호텔 ID |
| `hotelPath` | string | `pointHotels/{hotelId}` |
| `name`, `brand`, `locationText`, `address`, `imageUrl` | string | 호텔 스냅샷 |
| `loyaltyProgram`, `propertyCode` | string | 프로그램/숙소 코드 |
| `rating` | number | 평점 |
| `pointsPerNight`, `cashPerNightKrw` | number | 포인트/현금가 |
| `likedAt`, `updatedAt` | timestamp | 찜/수정 시각 |

### users/{uid}/hotel_reviews/{reviewId}

포인트 호텔 리뷰 미러입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `reviewPath` | string | `pointHotels/{hotelId}/reviews/{reviewId}` |
| `hotelId`, `hotelName`, `brand`, `locationText`, `imageUrl` | string | 호텔 정보 |
| `rating` | number | 1부터 5 |
| `content` | string | 리뷰 본문 |
| `createdAt` | timestamp | 작성 시각 |

### users/{uid}/branch_comments/{commentId}

상품권 지점 리뷰 미러입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `commentPath` | string | `branches/{branchId}/comments/{commentId}` |
| `branchId` | string | 지점 ID |
| `branchName` | string | 지점명 스냅샷 |
| `contentHtml` | string | 리뷰 HTML |
| `contentType` | string | `html` |
| `attachments` | array<map> | 첨부 이미지 |
| `createdAt`, `updatedAt` | timestamp | 작성/수정 시각 |

### users/{uid}/cardPreferenceProfiles/default

카드 추천 프로필입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `preferredAirline` | string | 선호 항공사 |
| `monthlySpendKRW` | number | 월 소비액 |
| `spendCategories` | map<string, number> | 카테고리별 소비액 |
| `usesOverseas`, `wantsLounge`, `usesGiftcard` | boolean | 선호 조건 |
| `benefitCategoryIds` | array<string> | 선호 혜택 |
| `maxAnnualFeeKRW` | number | 최대 연회비 |
| `maxPreviousMonthSpendKRW` | number | 최대 전월실적 |
| `mileValueKRW` | number | 1마일 가치 |
| `updatedAt` | timestamp | 수정 시각 |

### users/{uid}/travel_profile/default

레이더 개인화 프로필입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `homeAirports` | array<string> | 선호 출발 공항 |
| `preferredCabins` | array<string> | 선호 좌석 |
| `targetRegions` | array<string> | 관심 지역 |
| `dateFlexibility` | number | 일정 유연성 일수 |
| `mileageBalances` | map<string, number> | 항공사별 보유 마일 |
| `maxCashBudget` | number/null | 최대 현금 예산 |
| `giftcardEnabled` | boolean | 상품권 레이더 포함 여부 |
| `updatedAt` | timestamp | 수정 시각 |

### users/{uid}/radar_subscriptions/{subscriptionId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `type` | string | 레이더 항목 타입 |
| `conditions` | map | `title`, `route`, `dateRange`, `price`, `miles`, `source`, `payload` |
| `expiresAt` | timestamp | 만료 시각 |
| `isActive` | boolean | 활성 여부 |
| `pushEnabled` | boolean | 푸시 여부 |
| `peanutUsed` | number | 사용 땅콩 |
| `lastMatchedAt` | timestamp | 마지막 매칭 시각 |
| `createdAt`, `updatedAt` | timestamp | 생성/수정 시각 |

### users/{uid}/radar_notifications/{notificationId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `isRead` | boolean | 읽음 여부 |
| `readAt` | timestamp | 읽은 시각 |
| `createdAt` | timestamp | 생성 시각 |
| `payload` | map | 레이더 알림 데이터 |

### users/{uid}/giftcardDealAlerts/{alertId}

상품권 특가 알림 조건입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `name` | string | 알림명 |
| `scopeType` | string | `deal`, `custom` 등 |
| `dealIds`, `brandIds`, `merchantIds` | array<string> | 대상 조건 |
| `denominationsKRW` | array<number> | 액면가 조건 |
| `minDiscountRate` | number | 최소 할인율 |
| `maxPriceKRW` | number | 최대 구매가 |
| `enabled` | boolean | 활성 여부 |
| `notifyMode` | string | 현재 `improved_only` |
| `lastNotifiedDealId` | string | 마지막 알림 딜 |
| `lastNotifiedPriceKRW` | number | 마지막 알림 가격 |
| `lastNotifiedDiscountRate` | number | 마지막 알림 할인율 |
| `dealTitle`, `merchantName`, `brandName` | string | 표시 스냅샷 |
| `lastNotifiedAt`, `createdAt`, `updatedAt` | timestamp | 시각 필드 |

### users/{uid}/chat_usage/{yyyyMMdd}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `messageCount` | number | 일별 채팅 메시지 수 |
| `imageCount` | number | 일별 업로드 이미지 수 |
| `bytesUploaded` | number | 일별 업로드 바이트 |
| `updatedAt` | timestamp | 수정 시각 |

### users/{uid}/giftcard_meta/order

상품권 시세 화면 개인 순서 설정입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `branchIds` | array<string> | 선택 지점 |
| `giftcardIds` | array<string> | 선택 상품권 |
| `updatedAt` | timestamp | 수정 시각 |
| `updatedByUid` | string | 수정 사용자 |

---

## 3. posts/{yyyyMMdd}/posts/{postId}

커뮤니티 게시글입니다. 날짜별 문서 아래 `posts` 서브컬렉션을 둡니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `postId` | string | 문서 ID |
| `postNumber` | string | 전역 증가 번호, `meta/postNumber.number`에서 할당 |
| `boardId` | string | 게시판 ID |
| `title` | string | 제목 |
| `contentHtml` | string | 본문 HTML |
| `author` | map | 작성자 스냅샷 |
| `viewsCount` | number | 조회수 |
| `likesCount` | number | 좋아요 수 |
| `commentCount` | number | 댓글 수 |
| `reportsCount` | number | 신고 수 |
| `readRestriction` | map | 읽기 제한 |
| `labels` | array<map> | 커뮤니티 라벨 |
| `labelKeys` | array<string> | 라벨 키 목록 |
| `entityRefs` | map | 라벨 대상별 역참조 |
| `sourceChat` | map | 채팅에서 승격된 글일 때 원본 채팅 정보 |
| `isDeleted` | boolean | 삭제 여부 |
| `isHidden` | boolean | 숨김 여부 |
| `hiddenByReport` | boolean | 신고 누적 자동 숨김 여부 |
| `adminDeletedAt`, `restoredAt`, `hiddenAt`, `unhiddenAt` | timestamp | 관리자 처리 시각 |
| `createdAt` | timestamp | 작성 시각 |
| `updatedAt` | timestamp | 수정 시각 |

`author`:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `uid` | string | 작성자 UID |
| `displayName` | string | 닉네임 |
| `photoURL` | string | 프로필 이미지 |
| `displayGrade` | string | 등급 표시 |
| `currentSkyEffect` | string | 착용 이펙트 |

`readRestriction`:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `enabled` | boolean | 제한 사용 여부 |
| `minRank` | number | 최소 접근 rank |
| `minGrade` | string | 최소 등급 |
| `minLevel` | number | 최소 레벨 |
| `label` | string | UI 표시 |

`labels[]`:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `key` | string | 예: `branch:lotte_jamsil` |
| `type` | string | `branch`, `giftcard`, `card`, `calculator`, `feature` |
| `targetId` | string | 대상 ID |
| `displayName` | string | 표시명 |
| `subtitle` | string | 보조 표시 |
| `linkValue` | string | 내부 딥링크 |
| `sourcePath` | string | 원본 문서 경로 |

`entityRefs` 예:

```json
{
  "branchIds": ["lotte_jamsil"],
  "branchId": "lotte_jamsil",
  "giftcardIds": ["lotte"],
  "giftcardId": "lotte",
  "cardIds": ["card_abc"],
  "cardId": "card_abc",
  "calculatorKinds": ["giftcard"],
  "featureKinds": ["point_stay"],
  "featureKind": "point_stay"
}
```

### posts/{yyyyMMdd}/posts/{postId}/comments/{commentId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `commentId` | string | 댓글 ID |
| `uid` | string | 작성자 UID |
| `displayName` | string | 작성자 닉네임 |
| `profileImageUrl` | string | 작성자 프로필 이미지 |
| `displayGrade` | string | 등급 표시 |
| `currentSkyEffect` | string | 착용 이펙트 |
| `contentHtml` | string | 댓글 HTML |
| `contentType` | string | `html` |
| `attachments` | array<map> | 첨부 이미지 |
| `parentCommentId` | string/null | 부모 댓글 |
| `depth` | number | 0 원댓글, 1 답글 |
| `replyToUserId` | string/null | 답글 대상 UID |
| `mentionedUsers` | array<string> | 멘션 UID |
| `hasMention` | boolean | 멘션 여부 |
| `likesCount` | number | 댓글 좋아요 수 |
| `reportsCount` | number | 신고 수 |
| `isDeleted` | boolean | 삭제 여부 |
| `isHidden` | boolean | 숨김 여부 |
| `hiddenByReport` | boolean | 신고 자동 숨김 여부 |
| `createdAt`, `updatedAt` | timestamp | 작성/수정 시각 |

### comments/{commentId}/likes/{uid}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `uid` | string | 좋아요 사용자 |
| `likedAt` | timestamp | 좋아요 시각 |

### comments/{commentId}/reports/{uid}

댓글 로컬 신고 기록입니다. 전역 신고 문서는 `reports/comments/comments/{reportId}`에 저장됩니다.

### posts/{yyyyMMdd}/posts/{postId}/likes/{uid}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `uid` | string | 좋아요 사용자 |
| `likedAt` | timestamp | 좋아요 시각 |

### posts/{yyyyMMdd}/posts/{postId}/reports/{uid}

게시글 로컬 신고 기록입니다. 전역 신고 문서는 `reports/posts/posts/{reportId}`에 저장됩니다.

### 신고 사유

현재 UI에서 쓰는 커뮤니티 신고 사유:

| 값 | 설명 |
| --- | --- |
| `abuse` | 비방/욕설 |
| `copyright` | 저작권 |
| `advertisement` | 광고 |
| `other` | 기타 |

채팅 신고와 호텔 요청은 별도 `reason`, `detail` 문자열을 저장합니다.

---

## 4. 라벨별 게시글 인덱스

게시글에 라벨이 붙으면 목록 조회를 위해 아래 경로에 미러 문서를 만듭니다.

| 라벨 타입 | 경로 |
| --- | --- |
| `branch` | `branches/{branchId}/labeledPosts/{postId}` |
| `giftcard` | `giftcards/{giftcardId}/labeledPosts/{postId}` |
| `card` | `cards/catalog/cardProducts/{cardId}/labeledPosts/{postId}` |
| `feature` | `communityFeatures/{featureId}/labeledPosts/{postId}` |

공통 필드:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `postPath`, `postId`, `dateString` | string | 원본 게시글 위치 |
| `boardId`, `boardName` | string | 게시판 정보 |
| `title`, `previewText`, `imageUrl` | string | 표시 스냅샷 |
| `authorId`, `authorDisplayName`, `authorPhotoURL` | string | 작성자 스냅샷 |
| `commentCount`, `likesCount` | number | 반응 수 |
| `labelKey`, `labelType`, `targetId` | string | 라벨 키 |
| `labelDisplayName`, `labelSubtitle`, `labelLinkValue`, `labelSourcePath` | string | 라벨 표시 정보 |
| `isDeleted`, `isHidden` | boolean | 노출 제어 |
| `createdAt`, `updatedAt` | timestamp | 작성/갱신 시각 |

---

## 5. giftcards/{giftcardId}

상품권 브랜드입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `giftcardId` | string | 문서 ID |
| `name` | string | 표시명 |
| `logoUrl` | string | 로고 URL |
| `sortOrder` | number | 정렬값 |
| `bestSellPrice`, `bestSellRate`, `bestSellBranchId`, `bestSellBranchName` | number/string | 최고 매입가 요약 |
| `bestBuyPrice`, `bestBuyRate`, `bestBuyBranchId`, `bestBuyBranchName` | number/string | 최저 판매가 요약 |
| `updatedAt` | timestamp | 갱신 시각 |

서브컬렉션:
- `labeledPosts/{postId}`: 라벨 게시글 인덱스

---

## 6. branches/{branchId}

상품권 지점입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `branchId` | string | 문서 ID |
| `name` | string | 지점명 |
| `phone` | string | 연락처 |
| `openingHours` | map<string, string> | 영업시간 |
| `notice` | string/null | 안내사항 |
| `latitude`, `longitude` | number | 좌표 |
| `address` | string | 주소 |
| `createdByUid` | string | 최초 등록자 |
| `verified` | boolean | 검증 여부 |
| `isOfficialPartner` | boolean | 공식/검증 지점 표시 호환 필드 |

### branches/{branchId}/giftcardRates_current/{giftcardId}

현재 상품권 시세입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `giftcardId` | string | 상품권 ID |
| `sellPrice_general` | number | 사용자가 팔 때 가격 |
| `buyPrice_general` | number | 사용자가 살 때 가격 |
| `updatedAt` | timestamp | 갱신 시각 |

일부 화면은 차트/호환 목적으로 `sellPrice`, `buyPrice`, `sellPriceGeneral`, `buyPriceGeneral` 별칭도 읽습니다.

### branches/{branchId}/rates_daily/{yyyyMMdd}

일별 시세 스냅샷입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `date` | string | `yyyyMMdd` |
| `baseUnit` | number | 보통 100000 |
| `cards` | map | 상품권별 시세 맵 |

`cards.{giftcardId}`:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `buyPrice`, `buyRate` | number | 살 때 가격/수수료율 |
| `sellPrice`, `sellRate` | number | 팔 때 가격/수수료율 |

레거시/관리자 데이터에 따라 `cards` 맵 대신 문서 루트에 상품권 ID별 맵이 직접 들어올 수 있어, 읽기 코드는 두 형태를 함께 고려해야 합니다.

### branches/{branchId}/rates_monthly/{yyyyMM}

지점별 월간 상품권 판매 랭킹입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `users` | array<map> | `uid`, `displayName`, `photoUrl`, `saleId`, `sellTotal` |
| `firstUser`, `secondUser`, `thirdUser` | map/null | uid별 합산 Top 3 |
| `createdAt`, `updatedAt` | timestamp | 생성/수정 시각 |

### branches/{branchId}/comments/{commentId}

지점 리뷰입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `authorId`, `authorDisplayName`, `authorPhotoURL` | string | 작성자 |
| `profileImageUrl` | string | 호환용 프로필 이미지 |
| `contentHtml`, `plainText`, `contentType` | string | 본문 |
| `attachments` | array<map> | 첨부 이미지 |
| `branchId` | string | 지점 ID |
| `likesCount`, `reportsCount` | number | 반응 수 |
| `isDeleted`, `isHidden` | boolean | 노출 제어 |
| `createdAt`, `updatedAt` | timestamp | 작성/수정 시각 |

### branches/{branchId}/events/{eventId}

지점 이벤트입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `name` | string | 이벤트명 |
| `password` | string | 이벤트 인증값 |
| `peanutCount` | number | 지급 땅콩 |
| `isActive` | boolean | 활성 여부 |
| `branchId` | string | 지점 ID |
| `createdAt` | timestamp | 생성 시각 |

### branches/{branchId}/labeledPosts/{postId}

라벨 게시글 인덱스입니다.

---

## 7. 상품권 특가

### giftcardDeals/{dealId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `sourceId` | string | 소스 ID |
| `title` | string | 특가 제목 |
| `brandId`, `brandName` | string | 브랜드 |
| `merchantId`, `merchantName` | string | 판매처 |
| `denominationKRW`, `faceValueKRW` | number | 액면가 |
| `priceKRW` | number | 현재 판매가 |
| `discountRate` | number | 할인율 |
| `discountAmountKRW` | number | 할인액 |
| `buyUrl` | string | 구매 URL |
| `status` | string | `active`, `disabled`, `error`, `unknown` 등 |
| `lastSeenAt`, `lastChangedAt`, `updatedAt` | timestamp | 크롤링/변경/수정 시각 |

### giftcardDeals/{dealId}/priceHistory/{historyId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `priceKRW` | number | 가격 |
| `discountRate` | number | 할인율 |
| `discountAmountKRW` | number | 할인액 |
| `crawledAt` | timestamp | 수집 시각 |
| `status` | string | 수집 상태 |

크롤러 구현에 따라 원본 응답 일부가 추가 필드로 함께 저장될 수 있습니다.

### giftcardDealSources/{sourceId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `url`, `normalizedUrl` | string | 원본/정규화 URL |
| `merchantId`, `merchantName` | string | 판매처 |
| `brandId`, `brandName` | string | 브랜드 |
| `denominationKRW`, `faceValueKRW` | number | 액면가 |
| `displayName` | string | 표시명 |
| `enabled` | boolean | 크롤링 활성 여부 |
| `memo` | string | 메모 |
| `lastCrawlStatus`, `lastCrawlError` | string | 최근 수집 상태 |
| `lastPriceKRW`, `lastDiscountRate` | number | 최근 가격/할인율 |
| `lastCrawledAt` | timestamp | 최근 수집 시각 |
| `createdByUid`, `updatedByUid` | string | 작성/수정자 |
| `createdAt`, `updatedAt` | timestamp | 생성/수정 시각 |

### giftcardDealSourceRequests/{requestId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `url`, `normalizedUrl` | string | 요청 URL |
| `merchantId`, `merchantName` | string | 판매처 |
| `brandId`, `brandName` | string | 브랜드 |
| `denominationKRW`, `faceValueKRW` | number | 액면가 |
| `status` | string | `pending`, `approved`, `rejected` |
| `requesterUid`, `reviewedByUid` | string | 요청/검토자 |
| `sourceId` | string | 승인 후 생성된 소스 |
| `reviewNote` | string | 검토 메모 |
| `createdAt`, `updatedAt`, `reviewedAt` | timestamp | 시각 필드 |

---

## 8. 카드 카탈로그

루트 문서: `cards/catalog`

### cards/catalog/cardProducts/{cardId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `name` | string | 카드명 |
| `issuerName`, `issuerId` | string | 카드사 |
| `cardType` | string | `credit`, `check`, `hybrid`, `unknown` |
| `status` | string | `active`, `discontinued`, `hidden`, `pending` |
| `sourceType` | string | `userCreated` 등 |
| `rewardProgram` | string | 리워드 프로그램 |
| `annualFee` | map | 연회비 정보 |
| `previousMonthSpend` | map | 전월실적 |
| `primaryBenefits` | array | 주요 혜택 |
| `exclusions` | array | 제외 조건 |
| `benefitCategoryIds` | array<string> | 혜택 카테고리 |
| `mileagePrograms` | array<string> | 마일리지 프로그램 |
| `travelFlags` | map | 여행 혜택 플래그 |
| `loungeSummary` | map | 라운지 요약 |
| `eventSummary` | map | 이벤트 요약 |
| `sourceRefs` | map | 외부 소스 |
| `detailSummary` | string | 상세 요약 |
| `images` | map | `main.storagePath`, `main.downloadUrl`, `fileName`, `contentHash` 등 |
| `quality` | map | 품질/검수 정보 |
| `version` | number | 현재 버전 |
| `likesCount`, `commentsCount`, `viewsCount` | number | 반응 수 |
| `createdByUid`, `updatedByUid` | string | 작성/수정자 |
| `createdAt`, `updatedAt` | timestamp | 생성/수정 시각 |

서브컬렉션:

| 경로 | 설명 |
| --- | --- |
| `revisions/{revisionId}` | 변경 이력. `action`, `status`, `actorUid`, `versionFrom`, `versionTo`, `rollbackOfRevisionId`, `changeSet`, `createdAt` |
| `detailSections/{sectionId}` | 상세 섹션. `title`, `body`, `html`, `type`, `sortOrder` |
| `comments/{commentId}` | 카드 댓글. `cardId`, `parentCommentId`, `body`, `author`, `isDeleted`, `replyCount`, `createdAt`, `updatedAt` |
| `likes/{uid}` | 카드 좋아요 |
| `labeledPosts/{postId}` | 카드 라벨 게시글 인덱스 |

### cards/catalog/cardIssuers/{issuerId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `nameKo`, `nameEng` | string | 카드사명 |
| `logoUrl` | string | 로고 |
| `color` | string | 대표색 |
| `eventEnabled` | boolean | 이벤트 표시 여부 |
| `isVisible` | boolean | 노출 여부 |

### cards/catalog/cardEvents/{eventId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `title` | string | 이벤트명 |
| `issuerName` | string | 카드사 |
| `type` | string | 이벤트 타입 |
| `subject` | string | 대상 |
| `cardIds` | array<string> | 연결 카드 |
| `benefitAmountKRW` | number | 혜택 금액 |
| `benefitText` | string | 혜택 문구 |
| `applyUrl`, `sourceUrl` | string | 신청/출처 URL |
| `startsAt`, `endsAt` | timestamp | 기간 |
| `isVisible`, `isLive` | boolean | 노출/진행 여부 |

카드 이벤트 모델은 외부 크롤러 호환 필드로 `corpName`, `cashbackKRW`, `summary`, `eventUrl`, `startAt`, `endAt`도 읽습니다.

### cards/catalog/cardRankings/{rankingId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `title` | string | 랭킹 제목 |
| `basis` | string | 산정 기준 |
| `periodLabel` | string | 기간 표시 |
| `cardIds` | array<string> | 카드 ID 목록 |
| `calculatedAt` | timestamp | 계산 시각 |

### cards/catalog/cardRequests/{requestId}

사용자 카드 소스 요청입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `status` | string | `pending`, `imported`, `rejected` |
| `requesterUid`, `reviewedByUid` | string | 요청/검토자 |
| `query` | string | 검색어 |
| `candidate` | map | 후보 카드 스냅샷 |
| `existingCardId`, `importedCardId` | string | 기존/가져온 카드 |
| `createdAt`, `reviewedAt` | timestamp | 시각 |

### cards/catalog/cardChangeRequests/{requestId}

카드 변경 요청입니다. 서비스에서 경로를 노출하며 실제 필드는 Cloud Functions 구현에 따릅니다.

---

## 9. 항공권 특가와 알림

### deals/{dealId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `deal_id` | string | 딜 ID |
| `origin_city`, `origin_airport` | string | 출발 도시/공항 |
| `dest_city`, `dest_airport` | string | 도착 도시/공항 |
| `country_code` | string | 국가 코드 |
| `airline_code`, `airline_name` | string | 항공사 |
| `is_direct` | boolean | 직항 여부 |
| `via_count` | number | 경유 횟수 |
| `flight_duration` | string | 비행시간 |
| `price`, `price_display` | number/string | 가격 |
| `supply_start_date`, `supply_end_date` | string | `yyyyMMdd` |
| `date_ranges` | array<map> | `start`, `end` |
| `available_dates` | array<map> | `departure`, `return`, `departure_date`, `return_date`, `price` |
| `minimum_passengers` | number | 최소 인원 |
| `trip_type` | string | 왕복/편도 타입 |
| `master_id` | string | 원본 마스터 ID |
| `agency`, `agency_code` | string | 여행사 |
| `schedule_count` | number | 스케줄 수 |
| `outbound`, `inbound` | map | 항공편 정보 |
| `booking_url` | string | 예약 URL |
| `booking_data` | map | 예약 데이터 |
| `last_updated` | timestamp | 갱신 시각 |

`outbound`, `inbound`: `departure_time`, `arrival_time`, `origin_airport`, `dest_airport`, `airline_code`, `airline_name`, `flight_no`, `duration_text`.

### deals/{dealId}/price_history/{historyId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `price` | number | 가격 |
| `previous_price` | number | 이전 가격 |
| `price_change_percent` | number | 가격 변화율 |
| `recorded_at` | timestamp | 기록 시각 |

### deal_subscriptions/{uid}/items/{subscriptionId}

항공권 특가 알림 구독입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `region` | string | 지역 |
| `countries` | array<string> | 국가 |
| `airports` | array<string> | 도착 공항 |
| `originAirport` | string/null | 출발 공항 |
| `maxPrice` | number | 최대 가격 |
| `expiresAt` | timestamp | 만료 시각 |
| `createdAt` | timestamp | 생성 시각 |
| `peanutUsed` | number | 사용 땅콩 |
| `autoRenew` | boolean | 자동 갱신 |
| `notifiedDeals` | array<string> | 알림 발송 딜 |
| `isActive` | boolean | 활성 여부 |

### cancel_subscriptions/{uid}/items/{subscriptionId}

마일리지 취소표 알림 구독입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `from`, `to` | string | 출발/도착 공항 |
| `seatClasses` | array<string> | 좌석 코드 |
| `startDate`, `endDate` | timestamp | 탐색 기간 |
| `expiresAt` | timestamp | 만료 시각 |
| `createdAt` | timestamp | 생성 시각 |
| `peanutUsed` | number | 사용 땅콩 |
| `autoRenew` | boolean | 자동 갱신 |
| `notifiedDates` | array<string> | 알림 발송 날짜 |

### notification_history/{uid}/items/{itemId}

취소표 알림 히스토리입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `subscriptionId` | string | 구독 ID |
| `notifiedAt` | timestamp | 알림 시각 |
| `isRead` | boolean | 읽음 여부 |
| `data` | map | 알림 데이터 |

### popular_subscriptions/{routeKey}

취소표 인기 구독 집계입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `count` | number | 구독 수 |
| `lastUpdated` | timestamp | 최근 갱신 |

---

## 10. 레이더

### radar_items/{itemId}

서버 추천 레이더 항목입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `itemType` | string | `mileageSeat`, `cancelAlert`, `flightDeal`, `giftcard`, `benefitNews`, `valueCalculator`, `cardCalculator` |
| `title`, `subtitle`, `reason`, `source` | string | 표시 문구 |
| `route`, `dateRange` | string | 노선/기간 |
| `price`, `miles`, `cashValue` | number/null | 금액/마일 |
| `costPerMile` | number/null | 원/마일 |
| `urgency` | string | 긴급도 |
| `score` | number | 정렬 점수 |
| `deepLink` | string | 딥링크 |
| `updatedAt` | timestamp | 갱신 시각 |
| `payload` | map | 추가 데이터 |

---

## 11. 포인트 호텔

### pointHotels/{hotelId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `hotelId` | string | 호텔 ID |
| `status` | string | `active`만 목록 노출 |
| `name`, `city`, `country`, `address`, `brand` | string | 기본 정보 |
| `imageUrl`, `galleryUrls` | string/array | 이미지 |
| `rating`, `reviewCount` | number | 외부 평점/리뷰 수 |
| `guestFavorite` | boolean | 선호 숙소 여부 |
| `description` | string | 설명 |
| `amenities` | array<string> | 편의시설 |
| `amenityDetails` | array<map> | `title`, `subtitle`, `included` |
| `detailSections` | array<map> | `title`, `items[]` |
| `loyaltyProgram`, `propertyCode`, `officialUrl` | string | 프로그램/공식 정보 |
| `phone`, `checkInTime`, `checkOutTime`, `mapUrl` | string | 부가 정보 |
| `geo` | map | `lat`, `lng` |
| `currentAward` | map | `pointsPerNight`, `cashPerNightKrw` |
| `calendarPreview` | array<map> | `dateKey/date`, `pointsPerNight/points/p`, `cashPerNightKrw/cashKrw/c`, `available` |
| `sortScore` | number | 정렬 점수 |
| `milecatchRatingAverage`, `milecatchRatingCount`, `milecatchRatingSum` | number | 앱 리뷰 집계 |

좌표는 `geo.lat`/`geo.lng`를 우선 읽고, 호환 필드 `latitude`/`longitude` 또는 `lat`/`lng`도 지원합니다.

### pointHotels/{hotelId}/reviews/{reviewId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `reviewId`, `hotelId` | string | 리뷰/호텔 ID |
| `authorId`, `authorDisplayName`, `authorPhotoURL` | string | 작성자 |
| `rating` | number | 1부터 5 |
| `content` | string | 본문 |
| `hotelName`, `brand`, `locationText`, `imageUrl` | string | 호텔 스냅샷 |
| `isDeleted` | boolean | 삭제 여부 |
| `createdAt`, `updatedAt` | timestamp | 작성/수정 시각 |

### pointHotels/{hotelId}/calendarYears/{yyyy}

연도별 포인트 캘린더입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `days` | map | key: `dMMdd`, value: `{ "p": points, "c": cashKrw }` |

### pointAwardIndexes/{indexId}

포인트 숙박 추천 인덱스입니다. `indexId = {programId|all}_n{nights}_{sort}`.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `status` | string | `active` |
| `stale` | boolean | 오래된 인덱스 여부 |
| `updatedAt` | timestamp | 갱신 시각 |
| `items` | array<map> | 추천 호텔 항목 |

`items[]`: `candidateId`, `hotelId`, `programId`, `brand`, `name`, `city`, `country`, `address`, `imageUrl`, `loyaltyProgram`, `propertyCode`, `officialUrl`, `checkInDate`, `checkOutDate`, `nights`, `pointsTotal`, `cashTotalKrw`, `pointsPerNight`, `cashPerNightKrw`, `krwPerPoint`, `valueScore`, `rating`, `guestFavorite`, `confidence`, `updatedAt`.

---

## 12. 마일고사

루트 문서: `mockExam/main`

### mockExam/main/exams/{examId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `title` | string | 시험명 |
| `description` | string | 설명 |
| `status` | string | `draft`, `published`, `locked` |
| `roundNo` | number | 회차 |
| `questionCount` | number | 문제 수 |
| `totalScore` | number | 총점 |
| `timeLimitSeconds` | number | 제한 시간 |
| `categories` | array<string> | 카테고리 |

### mockExam/main/exams/{examId}/questions/{questionId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `category` | string | 카테고리 |
| `order` | number | 순서 |
| `score` | number | 배점 |
| `difficulty` | string | 난이도 |
| `question` | string | 문제 |
| `imageUrl` | string | 이미지 |
| `choices` | array<map> | `id`, `text` |
| `tags` | array<string> | 태그 |

### mockExam/main/users/{uid}/attempts/{attemptId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `examId`, `roundNo`, `status` | string/number | 시험/상태 |
| `score`, `totalScore`, `correctCount`, `questionCount` | number | 점수 |
| `durationSeconds` | number | 풀이 시간 |
| `categoryScores` | map<string, number> | 카테고리별 점수 |
| `answers` | array<map> | 응답 상세 |
| `isBestAttempt` | boolean | 최고 기록 여부 |
| `startedAt`, `submittedAt` | timestamp | 시작/제출 시각 |

`answers[]`: `questionId`, `selectedChoiceId`, `correctChoiceId`, `answerText`, `isCorrect`, `score`, `category`, `explanation`.

### mockExam/main/users/{uid}/progress/{examId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `examId` | string | 시험 ID |
| `completed` | boolean | 완료 여부 |
| `attemptCount` | number | 응시 횟수 |
| `bestScore`, `bestDurationSeconds` | number | 최고 기록 |
| `bestAttemptId` | string | 최고 응시 ID |
| `retryTickets`, `retryTicketsUsed` | number | 재도전권 |
| `shareRewardGranted` | boolean | 공유 보상 지급 여부 |
| `lastSubmittedAt` | timestamp | 최근 제출 |

### mockExam/main/leaderboards/{examId}/periods/all/entries/{uid}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `uid`, `displayName`, `photoUrl` | string | 사용자 |
| `score`, `durationSeconds` | number | 점수/시간 |
| `attemptId` | string | 응시 ID |
| `submittedAt` | timestamp | 제출 시각 |

---

## 13. 채팅

### chat_rooms/{roomId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `roomId` | string | 방 ID. 기본 `global` |
| `title` | string | 방 제목 |
| `description` | string | 설명 |
| `isActive` | boolean | 활성 여부 |
| `lastMessage` | string | 마지막 메시지 |
| `lastMessageAt` | timestamp | 마지막 메시지 시각 |
| `createdAt`, `updatedAt` | timestamp | 생성/수정 시각 |

### chat_rooms/{roomId}/messages/{messageId}

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `messageId` | string | 메시지 ID |
| `text` | string | 텍스트 |
| `imageUrls` | array<string> | 이미지 URL |
| `author` | map | `uid`, `displayName`, `photoURL`, `displayGrade`, `currentSkyEffect` |
| `isDeleted`, `isHidden` | boolean | 노출 제어 |
| `reportsCount` | number | 신고 수 |
| `createdAt`, `updatedAt` | timestamp | 생성/수정 시각 |

### chat_rooms/{roomId}/messages/{messageId}/reports/{reporterUid}

채팅 메시지 로컬 신고 기록입니다. 전역 신고 문서는 `reports/chat_messages/messages/{reportId}`에 저장됩니다.

---

## 14. 전역 신고

| 경로 | 설명 |
| --- | --- |
| `reports/posts/posts/{reportId}` | 게시글 신고 |
| `reports/comments/comments/{reportId}` | 댓글 신고 |
| `reports/chat_messages/messages/{reportId}` | 채팅 메시지 신고 |
| `reports/hotels/hotels/{reportId}` | 포인트 호텔 추가 요청 |

공통 필드:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `reportId` | string | 신고 ID |
| `reportPath` | string | 전역 신고 문서 경로 |
| `userReportPath` | string | 사용자 신고 미러 경로 |
| `type` | string | `post`, `comment`, `chat_message`, `hotel_request` |
| `reason`, `detail` | string | 사유/상세 |
| `reporterUid`, `reporterName` | string | 신고자 |
| `reportedAt` | timestamp | 신고 시각 |
| `status` | string | `pending`, `reviewed`, `resolved` 등 |
| `detailPath` | string | 대상 원본 경로 |

대상별 추가 필드:
- 게시글: `postId`, `dateString`, `boardId`, `postTitle`, `postAuthor`
- 댓글: `commentId`, `postId`, `dateString`, `commentAuthor`, `commentContent`
- 채팅: `roomId`, `messageId`, `messageAuthor`, `messageText`, `imageUrls`
- 호텔 요청: `hotelName`, `url`, `targetSummary`, `source`, `createdAt`, `updatedAt`

---

## 15. 관리자/시스템 컬렉션

### admin/deleted_posts/posts/{postId}

사용자 삭제 게시글 백업입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `originalPath` | string | 원본 게시글 경로 |
| `postId`, `dateString`, `boardId`, `title` | string | 게시글 식별 |
| `contentHtml` | string | 본문 |
| `author` | map | 작성자 |
| `viewsCount`, `likesCount`, `commentCount` | number | 반응 수 |
| `createdAt`, `deletedAt` | timestamp | 생성/삭제 시각 |
| `deletedBy` | string | 삭제 사용자 |
| `deletionType` | string | 예: `user_self_delete` |

### bottom_sheet_ads/{adId}

가이드/하단 광고입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `title` | string | 제목 |
| `imageUrl` | string | 이미지 URL |
| `linkType` | string | 링크 타입 |
| `linkValue` | string | 링크 값 |
| `isActive` | boolean | 활성 여부 |
| `priority` | number | 정렬 우선순위 |
| `startAt`, `endAt` | timestamp/null | 노출 기간 |
| `createdAt`, `updatedAt` | timestamp | 생성/수정 시각 |

### effects/{effectId}

스카이 이펙트 카탈로그입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `id` | string | 이펙트 ID |
| `name` | string | 표시명 |
| `grade` | string | 구매 가능 등급 |
| `level` | number | 구매 가능 레벨 |
| `price` | number | 땅콩 가격 |
| `lottieUrl` | string | Lottie URL |

### meta/postNumber

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `number` | number | 다음 게시글 번호 할당 기준 |

### meta/rates_monthly_v2/rates_monthly_v2/{yyyyMM}

전역 월간 상품권 판매 랭킹입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `users` | array<map> | `uid`, `displayName`, `photoUrl`, `saleId`, `sellTotal` |
| `createdAt`, `updatedAt` | timestamp | 생성/수정 시각 |

### notice/community

홈 화면 커뮤니티 공지 확인용 문서입니다. 상세 필드는 화면 표시 정책에 따릅니다.

---

## 16. 마일리지 좌석 데이터

### Firestore: dan/{routeDoc}, asiana/{routeDoc}

`routeDoc`는 `ICN-JFK` 같은 `출발-도착` 공항 코드입니다.

| 경로 | 설명 |
| --- | --- |
| `{airline}/{routeDoc}/flightInfo/meta` | 노선 메타. `aircraftType`, `departureCity`, `arrivalCity` 등 |
| `{airline}/{routeDoc}/latest/meta` | 최신 스냅샷 컬렉션 ID. 필드 `id` |
| `dan/{routeDoc}/{latestCollectionId}/snapshot` | 대한항공 좌석 스냅샷. `departureAirport`, `arrivalAirport`, `seatsByDate` |
| `asiana/{routeDoc}/{latestCollectionId}/{docId}` | 아시아나 날짜별 좌석 문서 |

`seatsByDate.{yyyyMMdd}` 또는 아시아나 날짜 문서:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `departureDate` | string | 출발일 |
| `departureAirport`, `arrivalAirport` | string | 공항 |
| `economy`, `business`, `first` | map | `mileage`, `amount` |
| `metadata.updatedAt` | string/timestamp | 갱신 정보 |

### Realtime Database 레거시

| 경로 | 설명 |
| --- | --- |
| `DAN/{routeDoc}/{itemId}` | 대한항공 레거시 좌석 |
| `ASIANA/{routeDoc}/{itemId}` | 아시아나 레거시 좌석 |

레거시 필드: `aircraftType`, `arrivalAirport`, `arrivalCity`, `arrivalDate`, `departureAirport`, `departureCity`, `departureDate`, `economyPrice`, `economySeat`, `businessPrice`, `businessSeat`, `firstPrice`, `firstSeat`, `uploadDate`.

---

## 17. Realtime Database

### CATEGORIES

커뮤니티 게시판 설정입니다.

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `id` | string | 게시판 ID |
| `name` | string | 표시명 |
| `group` | string | 그룹명 |
| `description` | string | 설명 |
| `icon` | string | Material icon 이름 |
| `fabEnabled` | boolean | 글쓰기 FAB 표시 여부 |
| `order` | number | 정렬값 |

현재 기본 게시판 ID:
`question`, `deal`, `hotdeal`, `seat_share`, `review`, `free`, `seats`, `news`, `aeroroute_news`, `secretflying_news`, `workingholiday_news`, `error_report`, `suggestion`, `milecatch_guide`, `notice`.

### VERSION

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `androidLatest` | string | Android 최신 버전 |
| `iosLatest` | string | iOS 최신 버전 |
| `latest` | string | 공통 최신 버전 |

---

## 18. 인덱스와 조회 패턴 메모

코드에서 자주 쓰는 조회 패턴입니다. Firestore 복합 인덱스가 필요할 수 있습니다.

| 컬렉션/그룹 | 조회 |
| --- | --- |
| `collectionGroup('posts')` | `boardId`, `isDeleted`, `isHidden`, `createdAt desc` |
| `collectionGroup('posts')` | `entityRefs.cardId == cardId`, `isDeleted == false`, `isHidden == false` |
| `posts/{date}/posts` | `createdAt desc`, `boardId` |
| `users/{uid}/lots` | `buyDate` 범위 + `orderBy('buyDate')` |
| `users/{uid}/sales` | `sellDate` 범위 + `orderBy('sellDate')`, `lotId whereIn` |
| `users/{uid}/cardTransactions` | `occurredAt` 월 범위 |
| `deals` | `origin_airport`, `dest_airport`, `agency_code`, `airline_code`, `price orderBy` |
| `giftcardDeals` | `discountRate desc` |
| `cards/catalog/cardProducts` | `status`, `updatedAt desc`, `likesCount desc` |
| `cards/catalog/cardIssuers` | `isVisible == true` |
| `cards/catalog/cardEvents` | `isVisible`, `isLive`, `cardIds arrayContains` |
| `pointHotels` | `status == active` |
| `pointHotels/{hotelId}/reviews` | `createdAt desc` |
| `mockExam/main/exams/{examId}/questions` | `order` |
| `chat_rooms/{roomId}/messages` | `createdAt desc` |
| `reports/*/*` | `reportedAt desc`, `status` |

---

## 19. 마이그레이션/호환성 메모

- 사용자 글 수는 `postsCount`를 사용합니다. 예전 `postCount`는 삭제 대상입니다.
- 사용자 `title`, `adBonusPercent`, `badgeVisible`, `reportSubmittedCount`, `reportedCount`, `warnCount`는 현재 마이그레이션 코드에서 삭제 대상으로 취급합니다.
- 게시판 정의는 Firestore `boards`가 아니라 Realtime Database `CATEGORIES`를 기준으로 읽습니다.
- 커뮤니티 게시글은 `labelKeys`, `labels`, `entityRefs`를 함께 저장해야 라벨별 목록과 딥링크가 정상 동작합니다.
- `users/{uid}/notifications`는 커뮤니티/시스템 알림함이고, `notification_history/{uid}/items`는 취소표 알림 히스토리입니다. 두 경로는 같은 알림함이 아닙니다.
- 상품권 구매 `lots`는 구매 당시 `mileRuleUsedPerMileKRW`, `miles`를 스냅샷으로 보존합니다.
- 상품권 판매 시 `lots.status = sold`, `lots.trade = true`로 갱신하고, 부분 판매는 남은 수량을 새 lot으로 분할합니다.
- 카드 카탈로그의 생성/수정/좋아요/댓글/랭킹 계산은 Cloud Functions를 통해 수행되며, Flutter는 위 모델 필드를 기준으로 읽습니다.
