# Marriott Hotel Metadata Update

이 폴더는 Marriott 호텔의 정적 메타데이터를 Firestore `pointHotels`에 업데이트하는 작업을 관리한다.

날짜별 포인트/현금가 캘린더 수집과는 분리한다. 호텔명, 주소, 좌표, 평점, 이미지, 편의시설 같은 호텔 기본 정보는 자주 바뀌지 않으므로 월 1회 갱신한다.

## 파일 구성

| 파일 | 역할 |
| --- | --- |
| `parse_marriott_hotel.js` | Marriott 호텔 overview 페이지를 열고 JSON-LD/HTML에서 호텔 정보를 파싱한다. |
| `run_marriott_hotel_parser_cdp.sh` | Chrome CDP 세션을 준비하고 단일 호텔 파싱과 업로드를 실행한다. |
| `upload_point_hotel.py` | 파싱된 JSON을 Firestore `pointHotels/{hotelId}`와 `pointHotelPrograms/marriott`에 업로드한다. |
| `update_marriott_hotels_from_firestore.py` | Firestore `pointHotels`에서 Marriott 호텔 목록을 읽고, 각 `officialUrl`을 파싱해서 다시 업로드한다. |
| `run_monthly_marriott_hotels_update.sh` | LaunchAgent가 호출하는 월간 실행 래퍼다. 로그, PATH, 중복 실행 lock을 처리한다. |
| `marriott_credentials.example.json` | `env/marriott.json` 형식 예시다. 실제 로그인 정보는 `env/`에 둔다. |

## 자동 실행

Mac mini에서는 LaunchAgent로 매달 1일 03:10에 실행되도록 등록되어 있다.

등록된 plist:

```text
~/Library/LaunchAgents/com.mileagethief.marriott-hotels-monthly.plist
```

LaunchAgent는 아래 래퍼를 실행한다.

```bash
/Users/vory/StudioProjects/mileage_thief/task/point/hotel/marriott/run_monthly_marriott_hotels_update.sh
```

실제 월간 업데이트 명령은 아래와 같다.

```bash
python3 /Users/vory/StudioProjects/mileage_thief/task/point/hotel/marriott/update_marriott_hotels_from_firestore.py
```

로그 위치:

```text
~/Library/Logs/mileage_thief/marriott-hotels-monthly.log
~/Library/Logs/mileage_thief/marriott-hotels-monthly.launchd.out.log
~/Library/Logs/mileage_thief/marriott-hotels-monthly.launchd.err.log
```

등록 상태 확인:

```bash
launchctl print "gui/$(id -u)/com.mileagethief.marriott-hotels-monthly"
```

수동 실행:

```bash
python3 /Users/vory/StudioProjects/mileage_thief/task/point/hotel/marriott/update_marriott_hotels_from_firestore.py
```

대상 목록만 확인:

```bash
python3 /Users/vory/StudioProjects/mileage_thief/task/point/hotel/marriott/update_marriott_hotels_from_firestore.py --dry-run
```

특정 호텔만 실행:

```bash
python3 /Users/vory/StudioProjects/mileage_thief/task/point/hotel/marriott/update_marriott_hotels_from_firestore.py --hotel-id marriott_selmm
```

파싱은 하되 Firestore에는 쓰지 않고 업로드 payload만 확인:

```bash
python3 /Users/vory/StudioProjects/mileage_thief/task/point/hotel/marriott/update_marriott_hotels_from_firestore.py --hotel-id marriott_selmm --dry-run-upload
```

## 새 Marriott 호텔 추가 방법

운영자가 새 호텔을 추가할 때는 Firestore `pointHotels/{hotelId}`에 seed 문서를 먼저 만든다.

필수 필드:

```json
{
  "hotelId": "marriott_cjuju",
  "programId": "marriott",
  "propertyCode": "CJUJU",
  "officialUrl": "https://www.marriott.com/ko/hotels/cjuju-jw-marriott-jeju-resort-and-spa/overview/",
  "status": "pending"
}
```

권장 규칙:

- `hotelId`는 `marriott_${propertyCode lowercase}` 형식을 사용한다.
- `programId`는 `marriott`로 고정한다.
- `propertyCode`는 Marriott 호텔 코드다. URL의 `/hotels/{code}-.../overview/`에서 확인할 수 있다.
- `officialUrl`은 Marriott 공식 overview URL을 넣는다.
- 새 호텔은 `status: pending`으로 넣는다.

월간 배치는 `status`가 `active` 또는 `pending`인 Marriott 호텔을 대상으로 실행된다. `pending` 호텔이 정상 파싱되면 업로드 과정에서 `status: active` 문서로 완성된다. 앱에서는 `status == active`만 조회하면 아직 파싱되지 않은 seed 문서가 노출되지 않는다.

## 사용자 요청으로 호텔을 추가하는 방향

앱 사용자가 직접 호텔 추가를 요청하는 기능을 만들 경우, 사용자가 `pointHotels`에 직접 쓰게 하지 않는다.

권장 흐름:

1. 앱은 `pointHotelRequests` 같은 요청 컬렉션에 사용자의 Marriott URL 또는 호텔명을 저장한다.
2. 서버 또는 운영자가 URL이 Marriott 공식 overview URL인지 검증한다.
3. 검증된 요청만 `pointHotels/{hotelId}`에 `status: pending` seed 문서로 만든다.
4. 월간 호텔 메타데이터 배치 또는 수동 단건 실행으로 실제 호텔 정보를 파싱한다.
5. 성공하면 `pointHotels/{hotelId}.status`가 `active`가 되어 앱에 노출된다.

이 구조를 쓰면 잘못된 URL, 중복 호텔, 악성 입력, 브랜드 불일치를 `pointHotels`에 바로 섞지 않을 수 있다.

## Firestore 업로드 결과

업로드 대상:

```text
pointHotelPrograms/marriott
pointHotels/{hotelId}
```

`pointHotels/{hotelId}`에는 아래 같은 필드가 채워진다.

- `hotelId`
- `programId`
- `loyaltyProgram`
- `propertyCode`
- `name`
- `city`
- `country`
- `address`
- `geo`
- `brand`
- `officialUrl`
- `phone`
- `checkInTime`
- `checkOutTime`
- `reviewCount`
- `rating`
- `guestFavorite`
- `imageUrl`
- `galleryUrls`
- `mapUrl`
- `description`
- `amenities`
- `amenityKeys`
- `amenityDetails`
- `detailSections`
- `searchTokens`
- `sortScore`
- `status`
- `metadataSource`
- `updatedAt`

날짜별 포인트/현금가 필드는 이 작업의 범위가 아니다. 캘린더 수집 작업에서 `pointHotels/{hotelId}/calendarYears`와 `calendarYearRuns`를 업데이트한다.

## 운영 메모

- Marriott direct fetch는 403이 자주 발생하므로 Chrome CDP 기반으로 파싱한다.
- 로그인 정보는 `env/marriott.json`에 둔다. 이 파일은 git에 올리지 않는다.
- Firebase service account도 `env/` 아래에 둔다.
- `run_monthly_marriott_hotels_update.sh`는 `/tmp/mileage_thief_marriott_hotels_monthly.lock`으로 중복 실행을 막는다.
- 파싱 결과 JSON은 기본적으로 `/tmp/marriott-hotel-meta-runs/<runId>/` 아래에 남는다.
- Mac이 꺼져 있으면 그 시각의 LaunchAgent 실행은 보장되지 않는다. 호텔 메타데이터는 월 1회 저빈도 작업이므로, 놓친 달은 필요 시 수동 실행한다.

## 다른 브랜드 확장 방식

Marriott 흐름이 안정되면 브랜드별로 같은 구조를 복제한다.

예상 구조:

```text
task/point/hotel/marriott/
task/point/hotel/hilton/
task/point/hotel/hyatt/
task/point/hotel/ihg/
task/point/hotel/accor/
```

브랜드별로 달라질 수 있는 부분:

- 공식 URL 패턴
- 호텔 코드 추출 방식
- 로그인 또는 봇 차단 우회 방식
- HTML/JSON-LD 파싱 규칙
- Firestore `programId`
- LaunchAgent 또는 서버 배치 실행 주기

Firestore 스키마는 가능하면 `pointHotels` 공통 규격을 유지하고, 브랜드별 차이는 파서 내부에서 정규화한다.
