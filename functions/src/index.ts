// functions/src/index.ts
// ✨ v2.0: 新增 sugar + fiber 營養素估算
import {setGlobalOptions} from "firebase-functions/v2/options";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";

admin.initializeApp();
setGlobalOptions({region: "asia-east1"});

// 🔐 Gemini API Key（從 Secret Manager 讀取）
const geminiApiKey = defineSecret("GEMINI_API_KEY");

// ============================================
// 📦 類型定義
// ============================================

type NotificationDoc = {
  to?: string;
  notification?: {title?: string; body?: string};
  data?: Record<string, string>;
  sent?: boolean;
  error?: string;
  errorCode?: string;
  sentAt?: FirebaseFirestore.FieldValue | Date;
  response?: string;
};

// Bounding Box 類型
interface BoundingBox {
  x_min: number;
  y_min: number;
  x_max: number;
  y_max: number;
}

// ✨ v2.0: 更新 FoodItem 增加 sugar 和 fiber
interface FoodItem {
  name: string;
  portion: string;
  portion_grams?: number;
  confidence: "high" | "medium" | "low";
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  sugar: number; // 🆕 糖 (g)
  fiber: number; // 🆕 膳食纖維 (g)
  notes?: string;
  bounding_box?: BoundingBox;
}

// ✨ v2.0: 更新 NutritionTotal 增加 sugar 和 fiber
interface NutritionTotal {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  sugar: number; // 🆕
  fiber: number; // 🆕
}

interface Recommendation {
  type: "immediate" | "next_meal" | "general";
  advice: string;
  reason: string;
}

interface FoodAnalysisResult {
  foods: FoodItem[];
  total: NutritionTotal;
  recommendations: Recommendation[];
  overall_confidence: "high" | "medium" | "low";
  meal_assessment?: {
    balance_score: number;
    strengths: string[];
    improvements: string[];
  };
}

interface AnalyzeFoodRequest {
  imageBase64: string;
  mealType?: string;
  userGoal?: string;
  targetCalories?: number;
}

// 🆕 重試配置
const MODELS = [
  "gemini-2.5-flash",
  "gemini-2.0-flash",
  "gemini-1.5-flash",
];
const MAX_RETRIES = 3;
const INITIAL_DELAY_MS = 1000;

/**
 * 清理 JSON 字串（移除 markdown 標記）
 * @param {string} text - 原始文字
 * @return {string} 清理後的 JSON 字串
 */
function cleanJsonString(text: string): string {
  let cleaned = text.trim();

  // 移除 markdown code block 標記
  if (cleaned.startsWith("```json")) {
    cleaned = cleaned.slice(7);
  } else if (cleaned.startsWith("```")) {
    cleaned = cleaned.slice(3);
  }

  if (cleaned.endsWith("```")) {
    cleaned = cleaned.slice(0, -3);
  }

  return cleaned.trim();
}

/**
 * 🆕 延遲函數
 * @param {number} ms - 延遲毫秒數
 * @return {Promise<void>}
 */
function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * 🆕 判斷是否為 503 錯誤
 * @param {string} message - 錯誤訊息
 * @return {boolean}
 */
function is503Error(message: string): boolean {
  return message.includes("503") ||
         message.includes("overloaded") ||
         message.includes("Service Unavailable") ||
         message.includes("UNAVAILABLE");
}

/**
 * 🆕 判斷是否為速率限制錯誤
 * @param {string} message - 錯誤訊息
 * @return {boolean}
 */
function isRateLimitError(message: string): boolean {
  return message.includes("429") ||
         message.includes("rate limit") ||
         message.includes("quota") ||
         message.includes("RESOURCE_EXHAUSTED");
}

/**
 * 🆕 判斷是否為可重試錯誤
 * @param {number} status - HTTP 狀態碼
 * @param {string} message - 錯誤訊息
 * @return {boolean}
 */
function isRetryableError(status: number, message: string): boolean {
  return status === 503 ||
         status === 429 ||
         status === 500 ||
         is503Error(message) ||
         isRateLimitError(message);
}

// ============================================
// 🍽️ AI 食物辨識 Function（v2.0 增加 sugar + fiber）
// ============================================

export const analyzeFood = onCall(
  {
    region: "asia-east1",
    secrets: [geminiApiKey],
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (request): Promise<{
    success: boolean;
    result?: FoodAnalysisResult;
    modelUsed?: string;
    error?: string;
  }> => {
    // 1. 驗證用戶已登入
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "請先登入");
    }

    // 2. 取得請求資料
    const {
      imageBase64,
      mealType,
      userGoal,
      targetCalories,
    } = request.data as AnalyzeFoodRequest;

    if (!imageBase64) {
      throw new HttpsError("invalid-argument", "請提供食物照片");
    }

    console.log(`📸 收到圖片，大小: ${imageBase64.length} 字元`);

    // 3. ✨ v2.0: 更新的 System Instruction（增加 sugar + fiber）
    const systemInstruction = `你是專業的營養師和食物辨識專家，專精於台灣飲食文化。

【核心任務】
準確辨識食物照片並估算營養成分，提供具體可行的飲食建議。
同時【精確標記】每個食物在圖片中的位置（bounding box）。

【辨識原則】
1. 優先使用台灣常見的食物名稱（如：滷肉飯、珍珠奶茶、蚵仔煎）
2. 份量估算參考台灣標準（如：一碗飯約200g、一份便當）
3. 營養數據參考衛福部食品營養資料庫
4. 對不確定的項目標註信心度（high/medium/low）

【✨ 營養素估算 - 6 項必填】
每個食物必須估算以下 6 種營養素：
1. calories (大卡) - 總熱量
2. protein (g) - 蛋白質
3. carbs (g) - 碳水化合物
4. fat (g) - 脂肪
5. sugar (g) - 糖（包含天然糖和添加糖）
6. fiber (g) - 膳食纖維

【糖分估算指南】
- 白飯、麵條：糖 ≈ 0-1g
- 水果：根據種類，約 10-15g/份
- 含糖飲料：約 25-50g
- 甜點、糕點：約 15-30g
- 炒菜、肉類：通常 < 3g（除非有糖醋、蜜汁等）

【膳食纖維估算指南】
- 白飯：約 0.3g/碗
- 蔬菜類：約 2-4g/份
- 水果類：約 2-3g/份
- 全穀類：約 3-5g/份
- 肉類、蛋類：0g
- 豆類：約 5-8g/份

【⚠️ Bounding Box 座標系統 - 請仔細閱讀！】
圖片座標使用 0-1000 的相對座標系統：
- 圖片左上角 = (0, 0)
- 圖片右下角 = (1000, 1000)
- 圖片正中央 = (500, 500)
- 圖片左半邊 x 約 0-500，右半邊 x 約 500-1000
- 圖片上半部 y 約 0-500，下半部 y 約 500-1000

【Bounding Box 欄位說明】
- x_min：食物最左邊的 x 座標（0-1000）
- y_min：食物最上邊的 y 座標（0-1000）
- x_max：食物最右邊的 x 座標（0-1000）
- y_max：食物最下邊的 y 座標（0-1000）

【⚠️ 定位步驟 - 請依序執行】
為每個食物標記 bounding box 時，請：
1. 先觀察食物在圖片中的相對位置（左/中/右、上/中/下）
2. 估算食物佔圖片的比例（例如：佔寬度 30%、高度 20%）
3. 計算具體座標數值
4. 確認框框緊貼食物邊緣

【座標範例參考】
- 左上角的小菜：x_min=50, y_min=50, x_max=300, y_max=250
- 正中央的主食：x_min=300, y_min=350, x_max=700, y_max=650
- 右下角的配菜：x_min=600, y_min=700, x_max=900, y_max=950
- 橫跨中間的長條食物：x_min=100, y_min=400, x_max=900, y_max=550

【精確度要求】
1. 框框必須緊貼食物實際邊緣
2. 不要框太大（包含空白或其他食物）
3. 不要框太小（切掉食物的一部分）
4. 重疊的食物要分別標記各自可見的區域
5. 座標誤差應控制在 ±50 以內

【常見錯誤 - 請避免】
❌ 所有食物都給類似的座標
❌ 框框明顯偏離食物實際位置
❌ 框框大小與食物實際大小不符
❌ 忽略食物的實際形狀（如長條形、圓形）

【輸出要求】
- 每項食物必須包含：名稱、份量、6種營養素、bounding_box
- 提供具體的飲食建議，不要空泛籠統
- 建議必須考慮用戶的健身目標
- 只輸出純 JSON，不要任何額外文字或 markdown 標記

【品質標準】
- 寧可說「無法確定」也不要猜測
- 複合食物要逐一拆解成分
- 烹調方式會影響熱量，要納入考量`;

    // 4. ✨ v2.0: 更新的 Prompt（增加 sugar + fiber）
    const prompt = `【任務】分析這張食物照片的營養成分，並【精確標記】每個食物的位置

【分析步驟 - 請依序執行】
1. 整體觀察：先看整張圖片，了解食物的整體分布
2. 逐一辨識：列出每個可見的食物品項
3. 精確定位：為每個食物計算 bounding_box
   - 先判斷食物在圖片的哪個區域（左上/中間/右下等）
   - 估算食物佔圖片的寬度和高度比例
   - 計算出 x_min, y_min, x_max, y_max（0-1000）
4. 估量：估算每項食物的份量
5. 計算：計算 6 種營養素（熱量、蛋白質、碳水、脂肪、糖、纖維）
6. 評估：標註信心度
7. 建議：提供3條具體建議

【用餐資訊】
- 餐別：${mealType || "一般餐點"}
${userGoal ? `- 健身目標：${userGoal}` : ""}
${targetCalories ? `- 每日目標熱量：${targetCalories}kcal` : ""}

【⚠️ Bounding Box 計算提醒】
座標系統：0-1000（左上角是原點）
- 如果食物在圖片左邊 1/3 處：x 約 0-333
- 如果食物在圖片中間：x 約 333-666
- 如果食物在圖片右邊 1/3 處：x 約 666-1000
- y 座標同理（上/中/下）

請仔細觀察每個食物的：
- 實際位置（不要猜測）
- 實際大小（框框要符合食物大小）
- 實際形狀（長條形、圓形、不規則形）

【⚠️ 營養素提醒】
- sugar (糖)：甜食、飲料、水果通常較高；白飯、肉類通常很低
- fiber (纖維)：蔬菜、水果、全穀較高；肉類、精製澱粉很低或為 0

【重要】只輸出純 JSON，不要包含任何 markdown 標記！

【輸出格式】
{
  "foods": [
    {
      "name": "食物名稱",
      "portion": "份量描述",
      "portion_grams": 克數,
      "confidence": "high/medium/low",
      "calories": 熱量數字,
      "protein": 蛋白質克數,
      "carbs": 碳水克數,
      "fat": 脂肪克數,
      "sugar": 糖克數,
      "fiber": 纖維克數,
      "bounding_box": {
        "x_min": 左邊界(0-1000),
        "y_min": 上邊界(0-1000),
        "x_max": 右邊界(0-1000),
        "y_max": 下邊界(0-1000)
      },
      "notes": "備註(可選)"
    }
  ],
  "total": {
    "calories": 總熱量,
    "protein": 總蛋白質,
    "carbs": 總碳水,
    "fat": 總脂肪,
    "sugar": 總糖,
    "fiber": 總纖維
  },
  "recommendations": [
    {
      "type": "immediate/next_meal/general",
      "advice": "具體建議",
      "reason": "原因說明"
    }
  ],
  "overall_confidence": "high/medium/low",
  "meal_assessment": {
    "balance_score": 1-10分,
    "strengths": ["優點1", "優點2"],
    "improvements": ["可改進1", "可改進2"]
  }
}`;

    // 5. 嘗試多個模型
    let lastError: Error | null = null;

    for (const modelName of MODELS) {
      console.log(`🤖 嘗試模型: ${modelName}`);

      for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
        console.log(`  📤 第 ${attempt} 次嘗試...`);

        try {
          const baseUrl = "https://generativelanguage.googleapis.com/v1beta";
          const apiUrl = `${baseUrl}/models/${modelName}:generateContent` +
            `?key=${geminiApiKey.value()}`;

          const response = await fetch(
            apiUrl,
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                system_instruction: {
                  parts: [{text: systemInstruction}],
                },
                contents: [
                  {
                    parts: [
                      {
                        inline_data: {
                          mime_type: "image/jpeg",
                          data: imageBase64,
                        },
                      },
                      {text: prompt},
                    ],
                  },
                ],
                generationConfig: {
                  responseMimeType: "application/json",
                  temperature: 0.2, // 降低到 0.2 提高穩定性
                  maxOutputTokens: 8192,
                },
              }),
            }
          );

          // 檢查 HTTP 狀態
          if (!response.ok) {
            const errorText = await response.text();
            console.log(`  ❌ HTTP ${response.status}: ${errorText.substring(0, 100)}`);

            // 判斷是否可重試
            if (isRetryableError(response.status, errorText)) {
              if (attempt < MAX_RETRIES) {
                const delayMs = INITIAL_DELAY_MS * Math.pow(2, attempt - 1);
                console.log(`  ⏳ 等待 ${delayMs}ms 後重試...`);
                await delay(delayMs);
                continue;
              }
            }

            lastError = new Error(`HTTP ${response.status}: ${errorText}`);
            break; // 跳到下一個模型
          }

          const result = await response.json();
          console.log("  📥 Gemini 回應:", JSON.stringify(result).substring(0, 300));

          // 6. 解析回應
          const text = result.candidates?.[0]?.content?.parts?.[0]?.text;
          const finishReason = result.candidates?.[0]?.finishReason;

          if (finishReason === "MAX_TOKENS") {
            console.log("  ⚠️ 回應被截斷 (MAX_TOKENS)");
          }

          if (!text) {
            console.log("  ❌ 無法取得回應文字");
            lastError = new Error("Gemini 回傳空內容");
            if (attempt < MAX_RETRIES) {
              await delay(INITIAL_DELAY_MS);
              continue;
            }
            break;
          }

          console.log("  📝 原始回應:", text.substring(0, 200));

          // 清理 JSON 字串
          const cleanedText = cleanJsonString(text);

          // 解析 JSON
          let analysisResult: FoodAnalysisResult;
          try {
            analysisResult = JSON.parse(cleanedText);
            console.log(`  ✅ 解析成功，辨識到 ${analysisResult.foods?.length || 0} 項食物`);
          } catch (parseError) {
            console.log(`  ❌ JSON 解析失敗: ${parseError}`);
            lastError = new Error(`JSON 解析失敗: ${parseError}`);
            if (attempt < MAX_RETRIES) {
              await delay(INITIAL_DELAY_MS);
              continue;
            }
            break;
          }

          // 驗證必要欄位
          if (!analysisResult.foods || !Array.isArray(analysisResult.foods)) {
            console.log("  ❌ 缺少 foods 欄位");
            lastError = new Error("分析結果缺少 foods 欄位");
            if (attempt < MAX_RETRIES) {
              await delay(INITIAL_DELAY_MS);
              continue;
            }
            break;
          }

          // ✨ v2.0: 確保每個食物都有 sugar 和 fiber 欄位（預設為 0）
          analysisResult.foods = analysisResult.foods.map((food) => ({
            ...food,
            sugar: food.sugar ?? 0,
            fiber: food.fiber ?? 0,
          }));

          // ✨ v2.0: 確保 total 也有 sugar 和 fiber
          if (analysisResult.total) {
            analysisResult.total.sugar = analysisResult.total.sugar ?? 0;
            analysisResult.total.fiber = analysisResult.total.fiber ?? 0;
          }

          // ✅ 成功！
          console.log(`✅ 使用 ${modelName} 分析成功`);

          // 7. 儲存到 Firestore
          const userId = request.auth.uid;
          await admin.firestore()
            .collection("users")
            .doc(userId)
            .collection("foodAnalysis")
            .add({
              ...analysisResult,
              mealType: mealType || "unknown",
              userGoal: userGoal || null,
              modelUsed: modelName,
              imageHash: imageBase64.substring(0, 32),
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

          console.log("✅ 分析完成並儲存");

          return {
            success: true,
            result: analysisResult,
            modelUsed: modelName,
          };
        } catch (error: unknown) {
          const err = error as Error;
          const errorMessage = err.message || String(error);
          console.log(`  ❌ 錯誤: ${errorMessage.substring(0, 100)}`);
          lastError = err;

          // 判斷是否可重試
          if (isRetryableError(0, errorMessage) && attempt < MAX_RETRIES) {
            const delayMs = INITIAL_DELAY_MS * Math.pow(2, attempt - 1);
            console.log(`  ⏳ 等待 ${delayMs}ms 後重試...`);
            await delay(delayMs);
            continue;
          }

          break; // 跳到下一個模型
        }
      }

      console.log(`  🔄 ${modelName} 失敗，嘗試下一個模型...`);
    }

    // 所有模型都失敗
    console.log("❌ 所有模型都失敗");
    const errorMessage = lastError?.message || "未知錯誤";

    // 🆕 詳細錯誤訊息
    let errorCode = "UNKNOWN_ERROR";
    let userMessage = "";

    if (is503Error(errorMessage)) {
      errorCode = "503_SERVICE_UNAVAILABLE";
      const modelList = MODELS.join(", ");
      userMessage = `[${errorCode}] AI 服務過載，已嘗試 ${MODELS.length} 個模型 ` +
        `(${modelList}) 都失敗。\n原因: ${errorMessage.substring(0, 100)}`;
    } else if (isRateLimitError(errorMessage)) {
      errorCode = "429_RATE_LIMIT";
      userMessage = `[${errorCode}] 請求過於頻繁，請稍後再試。\n` +
        `原因: ${errorMessage.substring(0, 100)}`;
    } else if (errorMessage.includes("API key")) {
      errorCode = "API_KEY_ERROR";
      userMessage = `[${errorCode}] API 金鑰問題。\n` +
        `原因: ${errorMessage.substring(0, 100)}`;
    } else if (errorMessage.includes("JSON")) {
      errorCode = "JSON_PARSE_ERROR";
      userMessage = `[${errorCode}] AI 回應格式錯誤。\n` +
        `原因: ${errorMessage.substring(0, 100)}`;
    } else {
      userMessage = `[${errorCode}] ${errorMessage}`;
    }

    throw new HttpsError("internal", userMessage);
  }
);

// ============================================
// 🔔 通知相關 Functions
// ============================================

export const sendNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event): Promise<void> => {
    const snapshot = event.data;
    if (!snapshot) return;

    const notificationData = snapshot.data() as NotificationDoc | undefined;
    if (!notificationData) return;

    const {to, notification, data, sent} = notificationData;

    if (sent === true) return;

    if (!to) {
      await snapshot.ref.update({
        sent: true,
        error: "Missing recipient token",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      } as NotificationDoc);
      return;
    }

    if (!notification || !notification.title) {
      await snapshot.ref.update({
        sent: true,
        error: "Missing notification content",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      } as NotificationDoc);
      return;
    }

    const message: admin.messaging.Message = {
      token: to,
      notification: {
        title: notification.title,
        body: notification.body || "",
      },
      data: (data as Record<string, string>) || {},
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "chat_channel",
          priority: "high",
        },
      },
      apns: {payload: {aps: {sound: "default", badge: 1}}},
    };

    try {
      const response = await admin.messaging().send(message);
      await snapshot.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        response,
      } as NotificationDoc);
    } catch (error: unknown) {
      const err = error as {message?: string; code?: string};
      await snapshot.ref.update({
        sent: true,
        error: err?.message || "Unknown error",
        errorCode: err?.code || "unknown",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      } as NotificationDoc);
    }
  }
);

export const cleanupOldNotifications = onSchedule(
  {schedule: "0 2 * * *", timeZone: "Asia/Taipei"},
  async (): Promise<void> => {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const qs = await admin
      .firestore()
      .collection("notifications")
      .where("sent", "==", true)
      .where("sentAt", "<", sevenDaysAgo)
      .limit(500)
      .get();

    if (qs.empty) return;

    const batch = admin.firestore().batch();
    qs.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
);

export const notifyPairRequest = onDocumentCreated(
  "pairRequests/{requestId}",
  async (event): Promise<void> => {
    const snap = event.data;
    if (!snap) return;

    const {toUserId, fromUserName} = snap.data() as {
      toUserId: string;
      fromUserName: string;
    };

    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(toUserId)
      .get();
    const fcmToken = userDoc.data()?.fcmToken as string | undefined;
    if (!fcmToken) return;

    await admin.firestore().collection("notifications").add({
      to: fcmToken,
      notification: {
        title: "新的配對請求",
        body: `${fromUserName} 想要與您配對`,
      },
      data: {
        type: "pair_request",
        requestId: event.params.requestId,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      sent: false,
    } as NotificationDoc);
  }
);
