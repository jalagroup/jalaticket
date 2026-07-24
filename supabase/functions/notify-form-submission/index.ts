import { createClient } from "npm:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const {
      form_id,
      submission_id,
      form_title,
      notify_email,
      additional_emails,
      additional_user_ids,
      custom_message,
    } = await req.json();

    if (!form_id || !submission_id) return json({ error: "Missing form_id or submission_id" }, 400);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    // Look up the form owner
    const { data: form } = await supabase
      .from("cc_forms")
      .select("owner_user_id, title")
      .eq("id", form_id)
      .single();

    if (!form) return json({ error: "Form not found" }, 404);

    // Look up the form owner's FCM tokens and email
    const { data: ownerUser } = await supabase
      .from("users")
      .select("fcm_token, fcm_token_web, email")
      .eq("id", form.owner_user_id)
      .maybeSingle();

    const title = form_title ?? form.title ?? "Custom Complaint";
    const body = custom_message ?? `تم تلقي طلب جديد على نموذج: ${title}`;
    const bodyEn = custom_message ?? `New submission received on form: ${title}`;

    // Collect all FCM tokens: owner + additional users
    const tokens: string[] = [];
    if (ownerUser?.fcm_token) tokens.push(ownerUser.fcm_token);
    if (ownerUser?.fcm_token_web) tokens.push(ownerUser.fcm_token_web);

    // Collect all email targets
    const emailTargets: string[] = [];
    if (notify_email) emailTargets.push(notify_email);
    if (Array.isArray(additional_emails)) {
      for (const e of additional_emails) {
        if (e && !emailTargets.includes(e)) emailTargets.push(e);
      }
    }

    // Look up additional user IDs for their tokens and emails
    if (Array.isArray(additional_user_ids) && additional_user_ids.length > 0) {
      const { data: additionalUsers } = await supabase
        .from("users")
        .select("fcm_token, fcm_token_web, email")
        .in("id", additional_user_ids);

      if (additionalUsers) {
        for (const u of additionalUsers) {
          if (u.fcm_token) tokens.push(u.fcm_token);
          if (u.fcm_token_web) tokens.push(u.fcm_token_web);
          if (u.email && !emailTargets.includes(u.email)) emailTargets.push(u.email);
        }
      }
    }

    // Fall back to owner email if no explicit notify_email and owner toggle was on
    if (emailTargets.length === 0 && ownerUser?.email) {
      emailTargets.push(ownerUser.email);
    }

    // Send FCM push notifications to all tokens
    const notifResults = await Promise.allSettled(
      tokens.map((token) =>
        supabase.functions.invoke("send-push-notification", {
          body: {
            token,
            title: `📋 ${title}`,
            body: bodyEn,
            data: {
              type: "cc_submission",
              form_id,
              submission_id,
            },
          },
        })
      )
    );

    // Send emails to all email targets, routed through send-email so they
    // get the System-Admin-designed template like every other email.
    let emailsSent = 0;
    if (emailTargets.length > 0) {
      const emailResults = await Promise.allSettled(
        emailTargets.map((emailTarget) =>
          supabase.functions.invoke("send-email", {
            body: {
              to: emailTarget,
              subject: `📋 ${title}`,
              title: `📋 ${title}`,
              message: `${bodyEn}\n\nSubmission ID: ${submission_id}`,
            },
          })
        )
      );
      emailsSent = emailResults.filter((r) => r.status === "fulfilled").length;
    }

    return json({
      ok: true,
      push_tokens_found: tokens.length,
      push_results: notifResults.map((r) => r.status),
      emails_sent: emailsSent,
      email_targets: emailTargets.length,
    });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
