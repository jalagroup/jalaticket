/**
 * auto-process-tickets — Supabase Edge Function
 *
 * Scheduled via pg_cron every hour. Calls the existing
 * auto_approve_expired_tickets() Postgres RPC which handles:
 *   - Standard prefinished tickets (no creator action within timeout)
 *   - Under-supervision prefinished tickets (same timeout, no action)
 *
 * After the batch it fires FCM push notifications to ticket creators.
 */

import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

// ─── helpers ────────────────────────────────────────────────────────────────

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function getFcmAccessToken(
  credentials: Record<string, string>,
): Promise<string> {
  const auth = new GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  if (!token.token) throw new Error("Failed to obtain FCM access token");
  return token.token;
}

async function sendPush(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
  projectId: string,
  accessToken: string,
): Promise<void> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          data,
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
        },
      }),
    },
  );
  if (!res.ok) {
    console.error(`FCM error (${res.status}):`, await res.text());
  }
}

// ─── main ───────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "GET" && req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }, 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    // ── 1. Run the existing batch auto-approval RPC ──────────────────────────
    // This single RPC handles both regular prefinished and supervised tickets.
    // It reads the timeout from system_settings.auto_approval_minutes.
    console.log("▶ Calling auto_approve_expired_tickets …");

    const { data: result, error: rpcErr } = await supabase.rpc(
      "auto_approve_expired_tickets",
    );

    if (rpcErr) {
      console.error("RPC error:", rpcErr);
      return json({ error: rpcErr.message }, 500);
    }

    // RPC returns: { approved_count: number, ticket_numbers: string[] }
    const approvedCount: number = result?.approved_count ?? 0;
    // ticket_numbers may come back as a JSON array string or a real array
    let ticketNumbers: string[] = [];
    if (Array.isArray(result?.ticket_numbers)) {
      ticketNumbers = result.ticket_numbers;
    } else if (typeof result?.ticket_numbers === "string") {
      try { ticketNumbers = JSON.parse(result.ticket_numbers); } catch (_) {}
    }

    console.log(`✅ Auto-approved ${approvedCount} ticket(s): ${ticketNumbers.join(", ")}`);

    if (approvedCount === 0) {
      return json({ success: true, approved_count: 0, ticket_numbers: [] });
    }

    // ── 2. Send push notifications to ticket creators ────────────────────────
    const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      console.warn("FCM_SERVICE_ACCOUNT not set — skipping notifications");
      return json({ success: true, approved_count: approvedCount, ticket_numbers: ticketNumbers });
    }

    let credentials: Record<string, string>;
    try {
      const parsed = JSON.parse(serviceAccountJson);
      credentials = typeof parsed === "string" ? JSON.parse(parsed) : parsed;
    } catch (e) {
      console.error("Invalid FCM_SERVICE_ACCOUNT JSON:", e);
      return json({ success: true, approved_count: approvedCount, ticket_numbers: ticketNumbers });
    }

    const accessToken = await getFcmAccessToken(credentials);

    // Fetch ticket rows by ticket_number to get creator IDs
    const { data: tickets, error: ticketErr } = await supabase
      .from("tickets")
      .select("id, ticket_number, created_by, under_supervision")
      .in("ticket_number", ticketNumbers);

    if (ticketErr || !tickets?.length) {
      console.error("Error fetching tickets:", ticketErr);
      return json({ success: true, approved_count: approvedCount, ticket_numbers: ticketNumbers });
    }

    // Fetch FCM tokens for all creators
    const creatorIds = [...new Set(tickets.map((t: { created_by: string }) => t.created_by))];
    const { data: users } = await supabase
      .from("users")
      .select("id, fcm_token, preferred_language")
      .in("id", creatorIds);

    const userMap = new Map(
      (users ?? []).map((u: { id: string; fcm_token?: string; preferred_language?: string }) => [u.id, u]),
    );

    for (const ticket of tickets) {
      const user = userMap.get(ticket.created_by) as
        | { fcm_token?: string; preferred_language?: string }
        | undefined;
      if (!user?.fcm_token) continue;

      const isAr = user.preferred_language === "ar";
      const wasSupervised = ticket.under_supervision;

      const title = isAr ? "تمت الموافقة التلقائية" : "Ticket Auto-Approved";
      const body = isAr
        ? `تمت الموافقة التلقائية على تذكرتك رقم ${ticket.ticket_number}${wasSupervised ? " (تحت الإشراف)" : ""}`
        : `Ticket #${ticket.ticket_number} was automatically approved${wasSupervised ? " (under supervision)" : ""}`;

      await sendPush(
        user.fcm_token,
        title,
        body,
        {
          type: "ticket_auto_approved",
          ticket_id: ticket.id,
          ticket_number: String(ticket.ticket_number),
          is_auto_approval: "true",
          was_supervised: String(wasSupervised ?? false),
        },
        credentials.project_id,
        accessToken,
      );
    }

    return json({
      success: true,
      approved_count: approvedCount,
      ticket_numbers: ticketNumbers,
    });
  } catch (e) {
    console.error("auto-process-tickets fatal error:", e);
    return json({ error: String(e) }, 500);
  }
});
