/**
 * auto-process-tickets — Supabase Edge Function
 *
 * Runs on a schedule (via pg_cron + pg_net) and handles two jobs:
 *   1. Auto-approve: closes prefinished tickets whose countdown has expired.
 *   2. Auto-approve supervised: closes prefinished+under_supervision tickets
 *      that have also exceeded their timeout (uses the same setting or a
 *      separate `auto_approval_minutes_supervised` key, falling back to the
 *      regular value).
 *
 * After each batch it fires push notifications to ticket creators using FCM.
 *
 * Can also be called manually (POST with optional secret header for testing).
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
  const tokenResponse = await client.getAccessToken();
  if (!tokenResponse.token) throw new Error("Failed to obtain FCM access token");
  return tokenResponse.token;
}

async function sendPushNotification(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
  credentials: Record<string, string>,
  accessToken: string,
): Promise<void> {
  const message = {
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
  };

  const res = await fetch(
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

  if (!res.ok) {
    const err = await res.text();
    console.error(`FCM error (${res.status}) for token ${fcmToken}: ${err}`);
  }
}

// ─── main ───────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  // Allow both GET (pg_net cron call) and POST (manual test)
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

    // ── FCM setup ────────────────────────────────────────────────────────────
    const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT");
    let fcmCredentials: Record<string, string> | null = null;
    let fcmAccessToken: string | null = null;

    if (serviceAccountJson) {
      try {
        const parsed = JSON.parse(serviceAccountJson);
        fcmCredentials =
          typeof parsed === "string" ? JSON.parse(parsed) : parsed;
        fcmAccessToken = await getFcmAccessToken(fcmCredentials!);
      } catch (e) {
        console.error("FCM credentials error — notifications will be skipped:", e);
      }
    }

    // ── 1. Auto-approve standard prefinished tickets ─────────────────────────
    console.log("▶ Running auto_approve_expired_tickets …");
    const { data: batchResult, error: batchErr } = await supabase.rpc(
      "auto_approve_expired_tickets",
    );
    if (batchErr) {
      console.error("auto_approve_expired_tickets error:", batchErr);
    }

    const approvedCount: number = batchResult?.approved_count ?? 0;
    const approvedTicketIds: string[] = batchResult?.ticket_ids ?? [];
    const approvedTicketNumbers: string[] = batchResult?.ticket_numbers ?? [];

    console.log(`✅ Auto-approved ${approvedCount} ticket(s): ${approvedTicketNumbers.join(", ")}`);

    // ── 2. Auto-approve supervised prefinished tickets ───────────────────────
    console.log("▶ Running auto_approve_supervised_tickets …");
    const { data: supResult, error: supErr } = await supabase.rpc(
      "auto_approve_supervised_tickets",
    );
    if (supErr) {
      // If the RPC doesn't exist yet, log and skip gracefully
      console.warn("auto_approve_supervised_tickets not available:", supErr.message);
    }

    const supApprovedCount: number = supResult?.approved_count ?? 0;
    const supApprovedTicketIds: string[] = supResult?.ticket_ids ?? [];
    const supApprovedTicketNumbers: string[] = supResult?.ticket_numbers ?? [];

    console.log(`✅ Auto-approved ${supApprovedCount} supervised ticket(s): ${supApprovedTicketNumbers.join(", ")}`);

    // ── 3. Send push notifications for all auto-approved tickets ─────────────
    const allApprovedIds = [...approvedTicketIds, ...supApprovedTicketIds];

    if (allApprovedIds.length > 0 && fcmCredentials && fcmAccessToken) {
      // Fetch creator FCM tokens for all approved tickets
      const { data: ticketRows, error: fetchErr } = await supabase
        .from("tickets")
        .select("id, ticket_number, created_by")
        .in("id", allApprovedIds);

      if (fetchErr) {
        console.error("Error fetching ticket rows:", fetchErr);
      } else if (ticketRows) {
        const creatorIds = [...new Set(ticketRows.map((t: { created_by: string }) => t.created_by))];

        // Fetch FCM tokens for creators
        const { data: users } = await supabase
          .from("users")
          .select("id, fcm_token, preferred_language")
          .in("id", creatorIds);

        const userMap = new Map(
          (users ?? []).map((u: { id: string; fcm_token: string; preferred_language: string }) => [u.id, u]),
        );

        for (const ticket of ticketRows) {
          const user = userMap.get(ticket.created_by) as { fcm_token?: string; preferred_language?: string } | undefined;
          if (!user?.fcm_token) continue;

          const isAr = user.preferred_language === "ar";
          const title = isAr ? "تمت الموافقة التلقائية" : "Auto-Approved";
          const body = isAr
            ? `تمت الموافقة على تذكرتك رقم ${ticket.ticket_number} تلقائياً`
            : `Ticket #${ticket.ticket_number} was automatically approved`;

          await sendPushNotification(
            user.fcm_token,
            title,
            body,
            {
              type: "ticket_auto_approved",
              ticket_id: ticket.id,
              ticket_number: String(ticket.ticket_number),
              is_auto_approval: "true",
            },
            fcmCredentials,
            fcmAccessToken,
          );
        }
      }
    }

    const totalApproved = approvedCount + supApprovedCount;
    return json({
      success: true,
      standard_approved: approvedCount,
      supervised_approved: supApprovedCount,
      total_approved: totalApproved,
      ticket_numbers: [...approvedTicketNumbers, ...supApprovedTicketNumbers],
    });
  } catch (e) {
    console.error("auto-process-tickets fatal error:", e);
    return json({ error: String(e) }, 500);
  }
});
