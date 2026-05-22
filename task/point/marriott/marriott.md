# Marriott point/cash calendar updater

이 폴더는 Marriott Bonvoy 호텔의 날짜별 포인트/현금가 캘린더를 Firestore에 업데이트한다. 호텔명, 이미지, 주소 같은 메타데이터는 `task/point/hotel/marriott/`에서 관리하고, 이 폴더는 `pointHotels/{hotelId}/calendarYears`와 `calendarYearRuns`만 담당한다.

## Files

| 파일 | 역할 |
| --- | --- |
| `capture_marriott_calendar.js` | Marriott availability calendar 페이지의 브라우저 세션 안에서 ADF GraphQL을 호출하고, 1년치 포인트/현금가를 연도별 `days` map JSON으로 정규화한다. |
| `run_marriott_calendar_capture.sh` | Playwright 실행 환경과 CDP Chrome을 준비한 뒤 `capture_marriott_calendar.js`를 실행한다. |
| `upload_marriott_calendar.py` | 정규화 JSON을 Firestore `calendarYears`, `calendarYearRuns`, `pointHotels.currentAward`, `calendarPreview`에 업로드한다. |
| `update_marriott_calendar_from_firestore.py` | Firestore `pointHotels`의 active Marriott 호텔을 읽고, 호텔별 1년치 캘린더 수집과 업로드를 순차 실행한다. |

## Batch update

등록된 Marriott 호텔 전체를 오늘부터 365일치로 업데이트한다.

```bash
python3 task/point/marriott/update_marriott_calendar_from_firestore.py
```

특정 호텔만 테스트한다.

```bash
python3 task/point/marriott/update_marriott_calendar_from_firestore.py \
  --hotel-id marriott_selmm \
  --days-ahead 31 \
  --dry-run-upload
```

`--dry-run-upload`는 Marriott 요청은 실제로 수행하되 Firestore write 대신 예정 payload를 출력한다. 호텔 목록만 확인하려면 `--dry-run`을 사용한다.

```bash
python3 task/point/marriott/update_marriott_calendar_from_firestore.py --dry-run
```

## Daily LaunchAgent

Mac mini에서는 LaunchAgent가 매일 한국시간 오전 7시에 Marriott 포인트/현금가 캘린더를 업데이트한다.

```text
~/Library/LaunchAgents/com.mileagethief.marriott-calendar-daily.plist
```

실행되는 스크립트:

```bash
task/point/marriott/run_daily_marriott_calendar_update.sh
```

로그:

```text
~/Library/Logs/mileage_thief/marriott-calendar-daily.log
~/Library/Logs/mileage_thief/marriott-calendar-daily.launchd.out.log
~/Library/Logs/mileage_thief/marriott-calendar-daily.launchd.err.log
```

기본 실행 옵션은 요청 사이 4초 대기, 403/일시 오류는 30초 간격으로 3회 재시도다. 먼 미래 window에서 Marriott/Akamai가 403을 반환하면 성공한 직전 구간까지만 Firestore에 업로드한다.

## Firestore target

캘린더 최신값은 날짜별 문서가 아니라 연도별 map 문서로 저장한다.

```text
pointHotels/{hotelId}/calendarYears/{yearKey}
pointHotels/{hotelId}/calendarYearRuns/{yearKey}_{runSlot}
```

날짜 key는 `dMMdd` 형식이다. 예를 들어 `2026-05-23`은 `calendarYears/2026.days.d0523`에 저장된다.

날짜 entry는 짧은 키를 사용한다.

```json
{
  "a": true,
  "p": 61000,
  "c": 636500,
  "v": 10.43,
  "src": "marriott_adf",
  "rid": "run_20260522_060000",
  "at": "serverTimestamp"
}
```

`a`는 포인트 숙박 가능 여부다. 현금가만 있고 포인트가 없으면 `a: false`로 저장한다.

## Collection strategy

- 기본 조건은 객실 1개, 성인 2명, 1박, KRW다.
- 기본 수집 범위는 실행일 기준 365일이다.
- Marriott 요청은 `--window-days 31` 기준으로 나누어 보낸다.
- 각 window마다 `points` 요청과 `cash` 요청을 각각 보내고, 같은 날짜 entry에 병합한다.
- Marriott/Akamai가 먼 미래 window에서 `403 Access Denied`를 반환하면 기본적으로 그 window 직전까지만 저장한다. 막힌 이후 날짜는 `예약불가`로 오해되지 않도록 Firestore에 쓰지 않는다.
- 값이 바뀐 날짜만 `calendarYearRuns.changedDays`에 남기고, 최신 조회용 문서는 `calendarYears`에 merge한다.
- `pointHotels.currentAward`는 수집 범위 안에서 포인트가 가장 낮은 날짜를 대표값으로 잡는다.
- `calendarPreview`는 수집 시작일부터 14일을 복사해 앱 목록과 상세 상단에서 빠르게 쓴다.

## Required source hotel fields

`update_marriott_calendar_from_firestore.py`는 아래 조건에 맞는 문서만 읽는다.

```text
pointHotels/{hotelId}
  programId: "marriott"
  status: "active"
  propertyCode: "SELMM"
```

`propertyCode`가 비어 있으면 `officialUrl`의 `/hotels/{code}-.../overview/` 경로에서 추출을 시도한다.

## Credentials and browser session

기본적으로 `env/marriott.json`을 사용해 로그인한다.

```json
{
  "memberNumber": "000000000",
  "password": "..."
}
```

CDP Chrome 프로필은 `/tmp/marriott-cdp-profile`을 사용한다. 같은 프로필을 계속 쓰므로 Akamai/쿠키 상태가 유지될 수 있다. 자동 로그인에서 보안 확인이나 MFA가 뜨면 브라우저 세션을 사람이 한 번 정리한 뒤 다시 실행하는 편이 안정적이다.
