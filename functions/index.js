const { onRequest } = require("firebase-functions/v2/https");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getAppCheck } = require("firebase-admin/app-check");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// ── 비용/남용 방어 설정 ────────────────────────────────────────────────
// 요청 본문(base64) 상한: 약 6MB 이미지까지 허용(그 이상은 413 거부).
const MAX_IMAGE_B64 = 8_000_000;
// 클라이언트가 임의의 고비용 모델을 지정하지 못하도록 허용 모델을 제한.
// (요청 body의 aiModel이 목록에 없으면 기본 모델로 강제)
const ALLOWED_MODELS = new Set([
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash",
  "gemini-2.0-flash",
  "gemini-2.0-flash-lite",
]);
const DEFAULT_MODEL = "gemini-2.5-flash-lite";

// Firebase Admin 초기화 (App Check 검증에 필요)
initializeApp();

exports.analyzeFood = onRequest(
  {
    secrets: [GEMINI_API_KEY],
    // 인스턴스 폭증에 따른 요금 폭탄 방지(동시 인스턴스 상한)
    maxInstances: 10,
    // 인스턴스당 동시 요청 수 — 큰 base64를 메모리에 들고 있으므로 보수적으로
    concurrency: 20,
    memory: "512MiB",
    timeoutSeconds: 60,
    // region 미지정: 기본 us-central1 유지(기존 호출 URL 불변)
  },
  async (req, res) => {
    // POST 외 메서드는 즉시 차단(프로빙/스팸이 작업을 유발하지 않도록)
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    // ── App Check 검증 ──────────────────────────────────────────────────
    // 등록된 앱(Play Integrity / DeviceCheck)에서 보낸 요청만 통과시킵니다.
    // 개발 시 디버그 토큰 설정:
    //   1) kDebugMode에서 앱 실행 → 콘솔에 출력되는 UUID 복사
    //   2) Firebase 콘솔 > App Check > 앱 > 디버그 토큰 관리 > UUID 등록
    const appCheckToken = req.header("X-Firebase-AppCheck");
    if (!appCheckToken) {
      res.status(401).json({ error: "Unauthorized: App Check token required" });
      return;
    }
    try {
      await getAppCheck().verifyToken(appCheckToken);
    } catch (err) {
      console.warn("App Check verification failed:", err.message);
      res.status(401).json({ error: "Unauthorized: Invalid App Check token" });
      return;
    }
    // ───────────────────────────────────────────────────────────────────

    try {
      const { imageBase64, detailedAnalysis, language, aiModel } = req.body;

      if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
        res.status(400).json({ error: "이미지 데이터가 필요합니다." });
        return;
      }
      if (imageBase64.length > MAX_IMAGE_B64) {
        res.status(413).json({ error: "이미지 용량이 너무 큽니다. 더 작은 사진을 사용해주세요." });
        return;
      }

      // 클라이언트가 보낸 모델을 허용 목록으로 제한(고비용 모델 강제 방지)
      const requestedModel =
        typeof aiModel === "string" && ALLOWED_MODELS.has(aiModel)
          ? aiModel
          : DEFAULT_MODEL;

      // ── 구조화 출력 스키마 ─────────────────────────────────────────────
      // Gemini가 자연어 대신 정해진 JSON을 반환하도록 강제한다.
      // 단위: calories=kcal(정수), 탄수화물/단백질/지방/식이섬유=g, 나트륨=mg
      const properties = {
        foodName: { type: "string" },
        calories: { type: "integer" },
        carbohydrates: { type: "number" },
        protein: { type: "number" },
        fat: { type: "number" },
        note: { type: "string" },
      };
      const required = ["foodName", "calories", "carbohydrates", "protein", "fat"];
      if (detailedAnalysis) {
        properties.sodium = { type: "number" };
        properties.fiber = { type: "number" };
      }

      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
      const model = genAI.getGenerativeModel({
        model: requestedModel,
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: { type: "object", properties, required },
        },
      });

      const langName =
        { "한국어": "Korean", "English": "English", "日本語": "Japanese" }[
          language ?? "한국어"
        ] || "Korean";

      const prompt =
        `You are a nutrition analysis assistant. Analyze the food in this photo and ` +
        `fill the provided JSON schema. Units: calories in kcal (integer); ` +
        `carbohydrates, protein, fat${detailedAnalysis ? ", fiber" : ""} in grams` +
        `${detailedAnalysis ? "; sodium in milligrams" : ""}. ` +
        `Estimate for a single typical serving shown in the photo. ` +
        `Write "foodName" and ${detailedAnalysis
          ? 'a detailed "note" (key ingredients, cooking method, glycemic index, etc.)'
          : 'a brief one-line "note"'} in ${langName}. ` +
        `If a value is uncertain, provide your best numeric estimate. ` +
        `If the image does not contain food, set foodName accordingly and use 0 for the numbers.`;

      const result = await model.generateContent([
        { inlineData: { data: imageBase64, mimeType: "image/jpeg" } },
        { text: prompt },
      ]);

      // 클라이언트는 result 문자열을 JSON으로 파싱한다(FoodAnalysis.parse).
      res.json({ result: result.response.text() });

    } catch (e) {
      // 내부 오류 상세는 서버 로그에만 남기고, 클라이언트에는 일반 메시지만 반환
      console.error(e);
      res.status(500).json({ error: "분석 중 오류가 발생했습니다." });
    }
  }
);
