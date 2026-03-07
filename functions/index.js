/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Firebase Admin SDK 초기화
admin.initializeApp();

const APP_SCHEME = "milecatchoauth";
const OAUTH_REGION = "asia-northeast3";
const NAVER_CLIENT_ID = defineSecret("NAVER_CLIENT_ID");
const NAVER_CLIENT_SECRET = defineSecret("NAVER_CLIENT_SECRET");
const KAKAO_REST_API_KEY = defineSecret("KAKAO_REST_API_KEY");
const KAKAO_CLIENT_SECRET = defineSecret("KAKAO_CLIENT_SECRET");

/**
 * unknown 값을 안전한 문자열 ID로 변환
 * @param {unknown} value
 * @return {string}
 */
function asIdString(value) {
  if (typeof value === "string") {
    return value.trim();
  }

  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }

  if (typeof value === "bigint") {
    return value.toString();
  }

  return "";
}

/**
 * optional 문자열 값을 null-safe 처리
 * @param {unknown} value
 * @return {string|null}
 */
function asOptionalString(value) {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * 네이버 프로필 payload를 앱에서 쓰기 쉬운 형태로 정규화
 * @param {Record<string, unknown>} payload
 * @return {{id: string, email: string|null, nickname: string|null, name: string|null, profileImage: string|null}}
 */
function normalizeNaverProfile(payload) {
  return {
    id: asIdString(payload.id),
    email: asOptionalString(payload.email),
    nickname: asOptionalString(payload.nickname),
    name: asOptionalString(payload.name),
    profileImage: asOptionalString(payload.profile_image),
  };
}

/**
 * 카카오 프로필 payload를 앱에서 쓰기 쉬운 형태로 정규화
 * @param {Record<string, unknown>} payload
 * @return {{id: string, email: string|null, nickname: string|null, name: string|null, profileImage: string|null}}
 */
function normalizeKakaoProfile(payload) {
  const kakaoAccount =
    payload && typeof payload.kakao_account === "object" &&
    payload.kakao_account !== null ?
      payload.kakao_account :
      {};
  const profile =
    kakaoAccount && typeof kakaoAccount.profile === "object" &&
    kakaoAccount.profile !== null ?
      kakaoAccount.profile :
      {};

  return {
    id: asIdString(payload.id),
    email: asOptionalString(kakaoAccount.email),
    nickname: asOptionalString(profile.nickname),
    name: asOptionalString(profile.nickname),
    profileImage: asOptionalString(profile.profile_image_url),
  };
}

/**
 * OAuth bridge query를 앱 callback URI로 변환
 * @param {Record<string, unknown>} query
 * @return {string}
 */
function buildNaverAppCallback(query) {
  const callbackUrl = new URL(`${APP_SCHEME}://oauth/naver`);

  const code = asOptionalString(query.code);
  const state = asOptionalString(query.state);
  const error = asOptionalString(query.error);
  const errorDescription = asOptionalString(query.error_description);

  if (code) {
    callbackUrl.searchParams.set("code", code);
  }

  if (state) {
    callbackUrl.searchParams.set("state", state);
  }

  if (error) {
    callbackUrl.searchParams.set("error", error);
  }

  if (errorDescription) {
    callbackUrl.searchParams.set("error_description", errorDescription);
  }

  return callbackUrl.toString();
}

/**
 * OAuth bridge query를 앱 callback URI로 변환
 * @param {string} provider
 * @param {Record<string, unknown>} query
 * @return {string}
 */
function buildOauthAppCallback(provider, query) {
  const callbackUrl = new URL(`${APP_SCHEME}://oauth/${provider}`);

  const code = asOptionalString(query.code);
  const state = asOptionalString(query.state);
  const error = asOptionalString(query.error);
  const errorDescription = asOptionalString(query.error_description);

  if (code) {
    callbackUrl.searchParams.set("code", code);
  }

  if (state) {
    callbackUrl.searchParams.set("state", state);
  }

  if (error) {
    callbackUrl.searchParams.set("error", error);
  }

  if (errorDescription) {
    callbackUrl.searchParams.set("error_description", errorDescription);
  }

  return callbackUrl.toString();
}

/**
 * boardId로 boardName을 가져오는 함수
 * @param {string} boardId - 게시판 ID
 * @return {Promise<string>} 게시판 이름
 */
async function getBoardName(boardId) {
  try {
    const snapshot = await admin.database()
        .ref(`categories/boards/${boardId}`)
        .once("value");

    if (snapshot.exists()) {
      return snapshot.val().name || "자유게시판";
    }
  } catch (error) {
    logger.error(`카테고리 정보 조회 실패: ${error.message}`);
  }

  // 기본값 반환
  const defaultBoardNames = {
    "free": "자유게시판",
    "question": "마일리지",
    "deal": "적립/카드 혜택",
    "seat_share": "좌석 공유",
    "review": "항공 리뷰",
    "error_report": "오류 신고",
    "suggestion": "건의사항",
    "notice": "운영 공지사항",
  };

  return defaultBoardNames[boardId] || "자유게시판";
}

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

/**
 * 게시글 좋아요 알림 Cloud Function
 * 트리거: posts/{date}/posts/{postId}/likes/{uid} onCreate
 *
 * 1번 사용자가 게시글을 생성
 * 2번 사용자가 해당 게시글을 좋아요함
 * → 1번 사용자의 디바이스에게 "2번 사용자가 게시글에 좋아요를 하였습니다." 알림 발송
 */
exports.onPostLikeCreated = onDocumentCreated({
  document: "posts/{date}/posts/{postId}/likes/{uid}",
  region: "asia-northeast3", // 서울 리전
}, async (event) => {
  try {
    const {date, postId, uid} = event.params;

    logger.info(`좋아요 알림 시작: postId=${postId}, likedBy=${uid}`);

    // 1. 게시글 정보 조회
    const postDoc = await admin.firestore()
        .doc(`posts/${date}/posts/${postId}`)
        .get();

    if (!postDoc.exists) {
      logger.error(`게시글을 찾을 수 없음: ${postId}`);
      return;
    }

    const postData = postDoc.data();
    const authorUid = postData.author.uid;
    const postTitle = postData.title;
    const boardId = postData.boardId || "free"; // 게시판 ID

    // boardId 기반으로 boardName 가져오기
    const boardName = await getBoardName(boardId);

    // 2. 자기 자신이 좋아요한 경우 알림 발송하지 않음
    if (authorUid === uid) {
      logger.info(`자기 자신이 좋아요한 경우 알림 발송하지 않음: ${uid}`);
      return;
    }

    // 3. 좋아요한 사용자 정보 조회
    const likerDoc = await admin.firestore()
        .collection("users")
        .doc(uid)
        .get();

    if (!likerDoc.exists) {
      logger.error(`좋아요한 사용자를 찾을 수 없음: ${uid}`);
      return;
    }

    const likerData = likerDoc.data();
    const likerName = likerData.displayName || "익명";

    // 4. 게시글 작성자의 FCM 토큰 조회
    const authorDoc = await admin.firestore()
        .collection("users")
        .doc(authorUid)
        .get();

    if (!authorDoc.exists) {
      logger.error(`게시글 작성자를 찾을 수 없음: ${authorUid}`);
      return;
    }

    const authorData = authorDoc.data();
    const fcmToken = authorData.fcmToken;

    if (!fcmToken) {
      logger.info(`게시글 작성자의 FCM 토큰이 없음: ${authorUid}`);
      return;
    }

    // 5. 알림 데이터를 사용자의 notifications 서브컬렉션에 저장
    const notificationData = {
      type: "post_like",
      postId: postId,
      postTitle: postTitle,
      boardId: boardId,
      boardName: boardName,
      likedBy: uid,
      likedByName: likerName,
      date: date,
      path: `/community/detail/${date}/${postId}`,
      title: "좋아요 알림",
      body: `${likerName}님이 게시글에 좋아요를 하였습니다.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };

    await admin.firestore()
        .collection("users")
        .doc(authorUid)
        .collection("notifications")
        .add(notificationData);

    logger.info(`알림 데이터 저장 완료: authorUid=${authorUid}, type=post_like`);

    // 6. FCM 메시지 발송
    const message = {
      token: fcmToken,
      data: {
        type: "post_like",
        postId: postId,
        postTitle: postTitle,
        boardId: boardId, // 게시판 ID 추가
        boardName: boardName, // 게시판 이름 추가
        likedBy: uid,
        likedByName: likerName,
        date: date,
        path: `/community/detail/${date}/${postId}`, // deeplink용 경로
        // 알림 표시용 데이터
        notificationTitle: "좋아요 알림",
        notificationBody: `${likerName}님이 게시글에 좋아요를 하였습니다.`,
        channelId: "post_like_notifications", // ✅ data로 이동
      },
      android: {
        priority: "high", // ✅ 알림 필드 없음
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info(`좋아요 알림 발송 성공: messageId=${response}`);

    logger.info(
        `좋아요 알림 완료: postId=${postId}, author=${authorUid}, liker=${uid}`,
    );
  } catch (error) {
    logger.error(`좋아요 알림 오류: ${error.message}`, error);
  }
});

/**
 * 댓글 알림 Cloud Function
 * 트리거: posts/{date}/posts/{postId}/comments/{commentId} onCreate
 *
 * 1번 사용자가 게시글을 생성
 * 2번 사용자가 해당 게시글에 댓글을 추가함
 * → 1번 사용자의 디바이스에게 "2번 사용자가 게시글에 댓글을 달았습니다." 알림 발송
 */
exports.onCommentCreated = onDocumentCreated({
  document: "posts/{date}/posts/{postId}/comments/{commentId}",
  region: "asia-northeast3", // 서울 리전
}, async (event) => {
  try {
    const {date, postId, commentId} = event.params;
    const commentData = event.data.data();

    logger.info(
        `댓글 알림 시작: postId=${postId}, commentId=${commentId}, ` +
        `commenter=${commentData.uid}`,
    );

    // 1. 게시글 정보 조회
    const postDoc = await admin.firestore()
        .doc(`posts/${date}/posts/${postId}`)
        .get();

    if (!postDoc.exists) {
      logger.error(`게시글을 찾을 수 없음: ${postId}`);
      return;
    }

    const postData = postDoc.data();
    const authorUid = postData.author.uid;
    const postTitle = postData.title;
    const boardId = postData.boardId || "free"; // 게시판 ID

    // boardId 기반으로 boardName 가져오기
    const boardName = await getBoardName(boardId);
    const commenterUid = commentData.uid;

    // 2. 대댓글인 경우 게시글 작성자에게 알림 발송하지 않음
    if (commentData.parentCommentId) {
      logger.info(`대댓글이므로 게시글 작성자에게 댓글 알림 발송하지 않음: ${commentId}`);
      return;
    }

    // 3. 자기 자신이 댓글을 단 경우 알림 발송하지 않음
    if (authorUid === commenterUid) {
      logger.info(`자기 자신이 댓글을 단 경우 알림 발송하지 않음: ${commenterUid}`);
      return;
    }

    // 4. 댓글 작성자 정보 조회
    const commenterDoc = await admin.firestore()
        .collection("users")
        .doc(commenterUid)
        .get();

    if (!commenterDoc.exists) {
      logger.error(`댓글 작성자를 찾을 수 없음: ${commenterUid}`);
      return;
    }

    const commenterData = commenterDoc.data();
    const commenterName = commenterData.displayName || "익명";

    // 5. 게시글 작성자의 FCM 토큰 조회
    const authorDoc = await admin.firestore()
        .collection("users")
        .doc(authorUid)
        .get();

    if (!authorDoc.exists) {
      logger.error(`게시글 작성자를 찾을 수 없음: ${authorUid}`);
      return;
    }

    const authorData = authorDoc.data();
    const fcmToken = authorData.fcmToken;

    if (!fcmToken) {
      logger.info(`게시글 작성자의 FCM 토큰이 없음: ${authorUid}`);
      return;
    }

    // 6. 알림 데이터를 사용자의 notifications 서브컬렉션에 저장
    const notificationData = {
      type: "post_comment",
      postId: postId,
      postTitle: postTitle,
      boardId: boardId,
      boardName: boardName,
      commentId: commentId,
      commentedBy: commenterUid,
      commentedByName: commenterName,
      date: date,
      path: `/community/detail/${date}/${postId}`,
      title: "댓글 알림",
      body: `${commenterName}님이 게시글에 댓글을 달았습니다.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };

    await admin.firestore()
        .collection("users")
        .doc(authorUid)
        .collection("notifications")
        .add(notificationData);

    logger.info(`알림 데이터 저장 완료: authorUid=${authorUid}, type=post_comment`);

    // 7. FCM 메시지 발송
    const message = {
      token: fcmToken,
      data: {
        type: "post_comment",
        postId: postId,
        postTitle: postTitle,
        boardId: boardId, // 게시판 ID 추가
        boardName: boardName, // 게시판 이름 추가
        commentId: commentId,
        commentedBy: commenterUid,
        commentedByName: commenterName,
        date: date,
        path: `/community/detail/${date}/${postId}`, // deeplink용 경로
        // 알림 표시용 데이터
        notificationTitle: "댓글 알림",
        notificationBody: `${commenterName}님이 게시글에 댓글을 달았습니다.`,
        channelId: "post_comment_notifications", // ✅ data로 이동
      },
      android: {
        priority: "high", // ✅ 알림 필드 없음
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info(`댓글 알림 발송 성공: messageId=${response}`);

    logger.info(
        `댓글 알림 완료: postId=${postId}, author=${authorUid}, ` +
        `commenter=${commenterUid}`,
    );
  } catch (error) {
    logger.error(`댓글 알림 오류: ${error.message}`, error);
  }
});

/**
 * 대댓글 알림 Cloud Function
 * 트리거: posts/{date}/posts/{postId}/comments/{commentId} onCreate
 * 조거: parentCommentId가 있는 경우만 (답글인 경우)
 *
 * 1번 사용자가 게시글에 댓글을 달음
 * 2번 사용자가 1번 사용자의 댓글에 대댓글을 달음
 * → 1번 사용자의 디바이스에게 "2번 사용자가 댓글에 댓글을 달았습니다." 알림 발송
 */
exports.onReplyCreated = onDocumentCreated({
  document: "posts/{date}/posts/{postId}/comments/{commentId}",
  region: "asia-northeast3", // 서울 리전
}, async (event) => {
  try {
    const {date, postId, commentId} = event.params;
    const commentData = event.data.data();

    // parentCommentId가 없는 경우 (원댓글인 경우) 처리하지 않음
    if (!commentData.parentCommentId) {
      logger.info(`원댓글이므로 대댓글 알림 처리하지 않음: ${commentId}`);
      return;
    }

    logger.info(
        `대댓글 알림 시작: postId=${postId}, commentId=${commentId}, ` +
        `replyTo=${commentData.parentCommentId}, replier=${commentData.uid}`,
    );

    const replierUid = commentData.uid;
    const parentCommentId = commentData.parentCommentId;

    // 1. 부모 댓글 정보 조회
    const parentCommentDoc = await admin.firestore()
        .doc(`posts/${date}/posts/${postId}/comments/${parentCommentId}`)
        .get();

    if (!parentCommentDoc.exists) {
      logger.error(`부모 댓글을 찾을 수 없음: ${parentCommentId}`);
      return;
    }

    const parentCommentData = parentCommentDoc.data();
    const parentCommenterUid = parentCommentData.uid;

    // 2. 자기 자신이 대댓글을 단 경우 알림 발송하지 않음
    if (parentCommenterUid === replierUid) {
      logger.info(
          `자기 자신이 대댓글을 단 경우 알림 발송하지 않음: ${replierUid}`,
      );
      return;
    }

    // 3. 대댓글 작성자 정보 조회
    const replierDoc = await admin.firestore()
        .collection("users")
        .doc(replierUid)
        .get();

    if (!replierDoc.exists) {
      logger.error(`대댓글 작성자를 찾을 수 없음: ${replierUid}`);
      return;
    }

    const replierData = replierDoc.data();
    const replierName = replierData.displayName || "익명";

    // 4. 부모 댓글 작성자의 FCM 토큰 조회
    const parentCommenterDoc = await admin.firestore()
        .collection("users")
        .doc(parentCommenterUid)
        .get();

    if (!parentCommenterDoc.exists) {
      logger.error(`부모 댓글 작성자를 찾을 수 없음: ${parentCommenterUid}`);
      return;
    }

    const parentCommenterData = parentCommenterDoc.data();
    const fcmToken = parentCommenterData.fcmToken;

    if (!fcmToken) {
      logger.info(`부모 댓글 작성자의 FCM 토큰이 없음: ${parentCommenterUid}`);
      return;
    }

    // 5. 게시글 정보 조회 (boardId, boardName용)
    const postDoc = await admin.firestore()
        .doc(`posts/${date}/posts/${postId}`)
        .get();

    let boardId = "free";
    let boardName = "자유게시판";

    if (postDoc.exists) {
      const postData = postDoc.data();
      boardId = postData.boardId || "free";

      // boardId 기반으로 boardName 매핑
      const boardNameMap = {
        "free": "자유게시판",
        "question": "마일리지",
        "deal": "적립/카드 혜택",
        "seat_share": "좌석 공유",
        "review": "항공 리뷰",
        "error_report": "오류 신고",
        "suggestion": "건의사항",
        "notice": "운영 공지사항",
      };
      boardName = boardNameMap[boardId] || "자유게시판";
    }

    // 6. 알림 데이터를 사용자의 notifications 서브컬렉션에 저장
    const notificationData = {
      type: "comment_reply",
      postId: postId,
      boardId: boardId,
      boardName: boardName,
      commentId: commentId,
      parentCommentId: parentCommentId,
      repliedBy: replierUid,
      repliedByName: replierName,
      date: date,
      path: `/community/detail/${date}/${postId}`,
      title: "대댓글 알림",
      body: `${replierName}님이 댓글에 댓글을 달았습니다.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };

    await admin.firestore()
        .collection("users")
        .doc(parentCommenterUid)
        .collection("notifications")
        .add(notificationData);

    logger.info(
        `알림 데이터 저장 완료: parentCommenterUid=${parentCommenterUid}, ` +
        `type=comment_reply`,
    );

    // 7. FCM 메시지 발송
    const message = {
      token: fcmToken,
      data: {
        type: "comment_reply",
        postId: postId,
        boardId: boardId, // 게시판 ID 추가
        boardName: boardName, // 게시판 이름 추가
        commentId: commentId,
        parentCommentId: parentCommentId,
        repliedBy: replierUid,
        repliedByName: replierName,
        date: date,
        path: `/community/detail/${date}/${postId}`, // deeplink용 경로
        // 알림 표시용 데이터
        notificationTitle: "대댓글 알림",
        notificationBody: `${replierName}님이 댓글에 댓글을 달았습니다.`,
        channelId: "comment_reply_notifications", // ✅ data로 이동
      },
      android: {
        priority: "high", // ✅ 알림 필드 없음
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info(`대댓글 알림 발송 성공: messageId=${response}`);

    logger.info(
        `대댓글 알림 완료: postId=${postId}, parentCommenter=${parentCommenterUid}, ` +
        `replier=${replierUid}`,
    );
  } catch (error) {
    logger.error(`대댓글 알림 오류: ${error.message}`, error);
  }
});

/**
 * 댓글 좋아요 알림 Cloud Function
 * 트리거: posts/{date}/posts/{postId}/comments/{commentId}/likes/{uid} onCreate
 *
 * 1번 사용자가 게시글을 생성
 * 2번 사용자가 해당 게시글에 댓글을 추가함
 * 3번 사용자가 2번 사용자의 댓글에 좋아요를 함
 * → 2번 사용자의 디바이스에게 "3번 사용자가 댓글에 좋아요를 하였습니다." 알림 발송
 */
exports.onCommentLikeCreated = onDocumentCreated({
  document: "posts/{date}/posts/{postId}/comments/{commentId}/likes/{uid}",
  region: "asia-northeast3", // 서울 리전
}, async (event) => {
  try {
    const {date, postId, commentId, uid} = event.params;

    logger.info(
        `댓글 좋아요 알림 시작: postId=${postId}, commentId=${commentId}, ` +
        `likedBy=${uid}`,
    );

    // 1. 댓글 정보 조회
    const commentDoc = await admin.firestore()
        .doc(`posts/${date}/posts/${postId}/comments/${commentId}`)
        .get();

    if (!commentDoc.exists) {
      logger.error(`댓글을 찾을 수 없음: ${commentId}`);
      return;
    }

    const commentData = commentDoc.data();
    const commenterUid = commentData.uid;
    const commenterName = commentData.displayName || "익명";

    // 2. 자기 자신이 좋아요한 경우 알림 발송하지 않음
    if (commenterUid === uid) {
      logger.info(
          `자기 자신이 댓글에 좋아요한 경우 알림 발송하지 않음: ${uid}`,
      );
      return;
    }

    // 3. 좋아요한 사용자 정보 조회
    const likerDoc = await admin.firestore()
        .collection("users")
        .doc(uid)
        .get();

    if (!likerDoc.exists) {
      logger.error(`좋아요한 사용자를 찾을 수 없음: ${uid}`);
      return;
    }

    const likerData = likerDoc.data();
    const likerName = likerData.displayName || "익명";

    // 4. 댓글 작성자의 FCM 토큰 조회
    const commenterDoc = await admin.firestore()
        .collection("users")
        .doc(commenterUid)
        .get();

    if (!commenterDoc.exists) {
      logger.error(`댓글 작성자를 찾을 수 없음: ${commenterUid}`);
      return;
    }

    const commenterUserData = commenterDoc.data();
    const fcmToken = commenterUserData.fcmToken;

    if (!fcmToken) {
      logger.info(`댓글 작성자의 FCM 토큰이 없음: ${commenterUid}`);
      return;
    }

    // 5. 게시글 정보 조회 (boardId, boardName용)
    const postDoc = await admin.firestore()
        .doc(`posts/${date}/posts/${postId}`)
        .get();

    let boardId = "free";
    let boardName = "자유게시판";

    if (postDoc.exists) {
      const postData = postDoc.data();
      boardId = postData.boardId || "free";

      // boardId 기반으로 boardName 매핑
      const boardNameMap = {
        "free": "자유게시판",
        "question": "마일리지",
        "deal": "적립/카드 혜택",
        "seat_share": "좌석 공유",
        "review": "항공 리뷰",
        "error_report": "오류 신고",
        "suggestion": "건의사항",
        "notice": "운영 공지사항",
      };
      boardName = boardNameMap[boardId] || "자유게시판";
    }

    // 6. 알림 데이터를 사용자의 notifications 서브컬렉션에 저장
    const notificationData = {
      type: "comment_like",
      postId: postId,
      boardId: boardId,
      boardName: boardName,
      commentId: commentId,
      likedBy: uid,
      likedByName: likerName,
      commenterName: commenterName,
      date: date,
      path: `/community/detail/${date}/${postId}`,
      title: "댓글 좋아요 알림",
      body: `${likerName}님이 댓글에 좋아요를 하였습니다.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };

    await admin.firestore()
        .collection("users")
        .doc(commenterUid)
        .collection("notifications")
        .add(notificationData);

    logger.info(
        `알림 데이터 저장 완료: commenterUid=${commenterUid}, ` +
        `type=comment_like`,
    );

    // 7. FCM 메시지 발송
    const message = {
      token: fcmToken,
      data: {
        type: "comment_like",
        postId: postId,
        boardId: boardId, // 게시판 ID 추가
        boardName: boardName, // 게시판 이름 추가
        commentId: commentId,
        likedBy: uid,
        likedByName: likerName,
        commenterName: commenterName,
        date: date,
        path: `/community/detail/${date}/${postId}`, // deeplink용 경로
        // 알림 표시용 데이터
        notificationTitle: "댓글 좋아요 알림",
        notificationBody: `${likerName}님이 댓글에 좋아요를 하였습니다.`,
        channelId: "comment_like_notifications", // ✅ data로 이동
      },
      android: {
        priority: "high", // ✅ 알림 필드 없음
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info(`댓글 좋아요 알림 발송 성공: messageId=${response}`);

    logger.info(
        `댓글 좋아요 알림 완료: postId=${postId}, commenter=${commenterUid}, ` +
        `liker=${uid}`,
    );
  } catch (error) {
    logger.error(`댓글 좋아요 알림 오류: ${error.message}`, error);
  }
});

/**
 * 네이버 OAuth 콜백을 앱 딥링크로 전달하는 브리지
 * Naver Console Callback URL에 이 함수 URL을 등록한다.
 */
exports.naverOauthBridge = onRequest({region: OAUTH_REGION}, (request, response) => {
  const hasCode = Boolean(asOptionalString(request.query?.code));
  const hasState = Boolean(asOptionalString(request.query?.state));
  const error = asOptionalString(request.query?.error);
  logger.info("naverOauthBridge callback received", {
    hasCode,
    hasState,
    error: error || null,
  });

  const redirectUrl = buildNaverAppCallback(request.query || {});
  response.set("Cache-Control", "no-store");
  response.redirect(302, redirectUrl);
});

/**
 * 카카오 OAuth 콜백을 앱 딥링크로 전달하는 브리지
 * Kakao Console Redirect URI에 이 함수 URL을 등록한다.
 */
exports.kakaoOauthBridge = onRequest({region: OAUTH_REGION}, (request, response) => {
  const hasCode = Boolean(asOptionalString(request.query?.code));
  const hasState = Boolean(asOptionalString(request.query?.state));
  const error = asOptionalString(request.query?.error);
  logger.info("kakaoOauthBridge callback received", {
    hasCode,
    hasState,
    error: error || null,
  });

  const redirectUrl = buildOauthAppCallback("kakao", request.query || {});
  response.set("Cache-Control", "no-store");
  response.redirect(302, redirectUrl);
});

/**
 * 네이버 OAuth code를 Firebase Custom Token으로 교환
 */
exports.createNaverCustomToken = onCall({
  region: OAUTH_REGION,
  secrets: [NAVER_CLIENT_ID, NAVER_CLIENT_SECRET],
}, async (request) => {
  const data = request.data || {};
  const code = asOptionalString(data.code) || "";
  const state = asOptionalString(data.state) || "";
  const redirectUri = asOptionalString(data.redirectUri) || "";

  if (!code || !state || !redirectUri) {
    throw new HttpsError(
        "invalid-argument",
        "code/state/redirectUri는 필수입니다.",
    );
  }

  try {
    const tokenUrl = new URL("https://nid.naver.com/oauth2.0/token");
    tokenUrl.searchParams.set("grant_type", "authorization_code");
    tokenUrl.searchParams.set("client_id", NAVER_CLIENT_ID.value());
    tokenUrl.searchParams.set("client_secret", NAVER_CLIENT_SECRET.value());
    tokenUrl.searchParams.set("code", code);
    tokenUrl.searchParams.set("state", state);
    tokenUrl.searchParams.set("redirect_uri", redirectUri);

    const tokenResponse = await globalThis.fetch(tokenUrl, {
      method: "GET",
      headers: {
        "Accept": "application/json",
      },
    });

    const tokenPayload = await tokenResponse.json();
    const accessToken = asOptionalString(tokenPayload.access_token) || "";

    if (!tokenResponse.ok || !accessToken) {
      logger.error("Naver token exchange failed", {
        status: tokenResponse.status,
        tokenPayload,
      });
      throw new HttpsError("internal", "네이버 토큰 발급에 실패했습니다.");
    }

    const profileResponse = await globalThis.fetch("https://openapi.naver.com/v1/nid/me", {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Accept": "application/json",
      },
    });

    const profilePayload = await profileResponse.json();
    const profileResponseBody = profilePayload && typeof profilePayload === "object" ?
      profilePayload.response || {} :
      {};
    const normalizedProfile = normalizeNaverProfile(profileResponseBody);
    const providerUid = normalizedProfile.id;

    if (!profileResponse.ok || !providerUid) {
      logger.error("Naver profile lookup failed", {
        status: profileResponse.status,
        profilePayload,
      });
      throw new HttpsError("internal", "네이버 프로필 조회에 실패했습니다.");
    }

    const firebaseUid = `naver:${providerUid}`;
    const firebaseToken = await admin.auth().createCustomToken(firebaseUid, {
      provider: "naver",
      providerUid,
    });

    return {
      firebaseToken,
      provider: "naver",
      providerUid,
      providerProfile: normalizedProfile,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error("createNaverCustomToken unexpected error", error);
    throw new HttpsError("internal", "네이버 로그인 처리 중 오류가 발생했습니다.");
  }
});

/**
 * 카카오 OAuth code를 Firebase Custom Token으로 교환
 */
exports.createKakaoCustomToken = onCall({
  region: OAUTH_REGION,
  secrets: [KAKAO_REST_API_KEY, KAKAO_CLIENT_SECRET],
}, async (request) => {
  const data = request.data || {};
  const code = asOptionalString(data.code) || "";
  const state = asOptionalString(data.state) || "";
  const redirectUri = asOptionalString(data.redirectUri) || "";

  if (!code || !state || !redirectUri) {
    throw new HttpsError(
        "invalid-argument",
        "code/state/redirectUri는 필수입니다.",
    );
  }

  try {
    const tokenBody = new URLSearchParams();
    tokenBody.set("grant_type", "authorization_code");
    tokenBody.set("client_id", KAKAO_REST_API_KEY.value());
    tokenBody.set("client_secret", KAKAO_CLIENT_SECRET.value());
    tokenBody.set("redirect_uri", redirectUri);
    tokenBody.set("code", code);

    const tokenResponse = await globalThis.fetch("https://kauth.kakao.com/oauth/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
        "Accept": "application/json",
      },
      body: tokenBody.toString(),
    });

    const tokenPayload = await tokenResponse.json();
    const accessToken = asOptionalString(tokenPayload.access_token) || "";

    if (!tokenResponse.ok || !accessToken) {
      logger.error("Kakao token exchange failed", {
        status: tokenResponse.status,
        tokenPayload,
      });
      throw new HttpsError("internal", "카카오 토큰 발급에 실패했습니다.");
    }

    const profileResponse = await globalThis.fetch("https://kapi.kakao.com/v2/user/me", {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Accept": "application/json",
      },
    });

    const profilePayload = await profileResponse.json();
    const normalizedProfile = normalizeKakaoProfile(profilePayload || {});
    const providerUid = normalizedProfile.id;

    if (!profileResponse.ok || !providerUid) {
      logger.error("Kakao profile lookup failed", {
        status: profileResponse.status,
        profilePayload,
      });
      throw new HttpsError("internal", "카카오 프로필 조회에 실패했습니다.");
    }

    const firebaseUid = `kakao:${providerUid}`;
    const firebaseToken = await admin.auth().createCustomToken(firebaseUid, {
      provider: "kakao",
      providerUid,
    });

    return {
      firebaseToken,
      provider: "kakao",
      providerUid,
      providerProfile: normalizedProfile,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error("createKakaoCustomToken unexpected error", error);
    throw new HttpsError("internal", "카카오 로그인 처리 중 오류가 발생했습니다.");
  }
});

/**
 * 테스트용 함수 (배포 후 확인용)
 */
exports.helloWorld = onRequest((request, response) => {
  logger.info("Hello logs!", {structuredData: true});
  response.send("Hello from Firebase Functions!");
});
