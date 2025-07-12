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
const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Firebase Admin SDK 초기화
admin.initializeApp();

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
    const boardName = boardNameMap[boardId] || "자유게시판";

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

    // 5. FCM 메시지 발송
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
      },
      android: {
        notification: {
          channelId: "post_like_notifications",
          priority: "high",
        },
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
    const boardName = boardNameMap[boardId] || "자유게시판";
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

    // 6. FCM 메시지 발송
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
      },
      android: {
        notification: {
          channelId: "post_comment_notifications",
          priority: "high",
        },
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

    // 6. FCM 메시지 발송
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
      },
      android: {
        notification: {
          channelId: "comment_reply_notifications",
          priority: "high",
        },
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

    // 6. FCM 메시지 발송
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
      },
      android: {
        notification: {
          channelId: "comment_like_notifications",
          priority: "high",
        },
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
 * 테스트용 함수 (배포 후 확인용)
 */
exports.helloWorld = onRequest((request, response) => {
  logger.info("Hello logs!", {structuredData: true});
  response.send("Hello from Firebase Functions!");
});
