# Korean Air award crawler

이 폴더는 대한항공 마일리지 좌석 정보를 수집해서 Firestore `dan` snapshot과 커뮤니티 `posts` 게시글로 업로드한다.

## Files

| 파일 | 역할 |
| --- | --- |
| `capture_korean_air_award.js` | CDP Chrome에 붙어 대한항공 로그인 세션에서 award API를 호출하고 정규화 JSON을 만든다. |
| `run_korean_air_capture.sh` | Playwright runner와 CDP Chrome을 준비한 뒤 캡처 JS를 실행한다. |
| `upload_korean_air_award.py` | 정규화 JSON을 `dan/{routeKey}/{timestampKey}/snapshot`, `latest/meta`, `posts`에 업로드한다. |
| `run_korean_air_award.py` | 수동 실행과 LaunchAgent 실행이 함께 쓰는 메인 오케스트레이터다. |
| `run_korean_air_daily.sh` | LaunchAgent가 호출하는 래퍼다. 로그와 중복 실행 lock을 처리한다. |
| `com.mileagethief.korean-air-daily.plist` | 매일 07:00, 13:00, 20:00 실행용 LaunchAgent plist다. |

## Credentials

실제 계정 정보는 gitignore된 `env/korean_air.json`에 둔다.

```json
{
  "userId": "SKYPASS_ID",
  "password": "PASSWORD",
  "traveler": {
    "fqtvNumber": "123456789012",
    "lastName": "LAST",
    "firstName": "FIRST"
  }
}
```

Firebase Admin은 `env/mileagethief-firebase-adminsdk-8gdf2-49e348f31e.json`을 고정 경로로 읽는다.

## Immediate run

전체 기본 노선, 360일, Firestore와 posts 업로드:

```bash
python3 task/korean/run_korean_air_award.py
```

1개 노선만 실제 캡처하고 Firestore write는 출력만 확인:

```bash
python3 task/korean/run_korean_air_award.py \
  --route ICN-PQC \
  --days-ahead 31 \
  --dry-run-upload
```

대표 테스트 옵션:

```bash
python3 task/korean/run_korean_air_award.py \
  --route ICN-PQC \
  --limit-routes 1 \
  --days-ahead 31 \
  --dry-run-upload \
  --skip-post-upload \
  --output-dir /tmp/korean-air-runs/test
```

## LaunchAgent

등록 위치:

```text
~/Library/LaunchAgents/com.mileagethief.korean-air-daily.plist
```

스케줄은 매일 07:00, 13:00, 20:00이다.

로그:

```text
~/Library/Logs/mileage_thief/korean-air-daily.log
~/Library/Logs/mileage_thief/korean-air-daily.launchd.out.log
~/Library/Logs/mileage_thief/korean-air-daily.launchd.err.log
```

CDP Chrome은 포트 `9223`, 프로필 `/tmp/korean-air-cdp-profile`을 쓴다. 보안 확인이나 추가 인증이 뜨면 이 Chrome 세션에서 사람이 한 번 처리한 뒤 다시 실행한다.
