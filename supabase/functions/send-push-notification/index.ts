import "@supabase/functions-js/edge-runtime.d.ts";
import { GoogleAuth } from "npm:google-auth-library@9";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

async function getAccessToken(credentials: Record<string, string>): Promise<string> {
  const auth = new GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const client = await auth.getClient();
  const tokenResponse = await client.getAccessToken();
  if (!tokenResponse.token) throw new Error("Failed to obtain access token");
  return tokenResponse.token;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const { token, title, body, data } = await req.json();

    if (!token || !title || !body) {
      return json({ error: "Missing required fields: token, title, body" }, 400);
    }

    const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      return json({ error: "FCM_SERVICE_ACCOUNT secret not configured" }, 500);
    }

    let credentials: Record<string, string>;
    try {
      const parsed = JSON.parse(serviceAccountJson);
      credentials = typeof parsed === "string" ? JSON.parse(parsed) : parsed;
    } catch (e) {
      const preview = serviceAccountJson.substring(0, 80).replace(/\n/g, "\\n");
      return json({
        error: "FCM_SERVICE_ACCOUNT is not valid JSON",
        preview: `"${preview}..."`,
        parse_error: String(e),
      }, 500);
    }

    const accessToken = await getAccessToken(credentials);

    const message = {
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data ?? {}).map(([k, v]) => [k, String(v)]),
      ),
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channel_id: "high_importance_channel",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: {
          aps: {
            alert: { title, body },
            sound: "default",
            badge: 1,
            "content-available": 1,
          },
        },
      },
    };

    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${credentials.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ message }),
      },
    );

    if (!fcmRes.ok) {
      const err = await fcmRes.text();
      return json({ error: `FCM error (${fcmRes.status}): ${err}` }, fcmRes.status);
    }

    const result = await fcmRes.json();
    return json({ success: true, result });
  } catch (e) {
    console.error("send-push-notification error:", e);
    return json({ error: String(e) }, 500);
  }
});
