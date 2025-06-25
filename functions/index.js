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

    // 5. 알림 메시지 생성
    const notification = {
      title: "좋아요 알림",
      body: `${likerName}님이 게시글에 좋아요를 하였습니다.`,
    };

    // 6. FCM 메시지 발송
    const message = {
      token: fcmToken,
      notification: notification,
      data: {
        type: "post_like",
        postId: postId,
        postTitle: postTitle,
        likedBy: uid,
        likedByName: likerName,
        date: date,
        path: `/community/detail/${date}/${postId}`, // deeplink용 경로
      },
      android: {
        notification: {
          channelId: "post_notifications",
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
 * 테스트용 함수 (배포 후 확인용)
 */
exports.helloWorld = onRequest((request, response) => {
  logger.info("Hello logs!", {structuredData: true});
  response.send("Hello from Firebase Functions!");
});
