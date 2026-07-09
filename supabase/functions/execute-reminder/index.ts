import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// ── Schedule helpers ──────────────────────────────────────────────────────────

function computeNextRunAt(scheduleType: string, config: Record<string, unknown>): Date {
  const now = new Date();

  if (scheduleType === "interval") {
    const minutes = (config.every_minutes as number) ?? 60;
    return new Date(now.getTime() + minutes * 60_000);
  }

  if (scheduleType === "daily") {
    const times = (config.times as string[]) ?? ["09:00"];
    const todayTimes = times
      .map((t) => {
        const [h, m] = t.split(":").map(Number);
        const d = new Date(now);
        d.setHours(h, m, 0, 0);
        return d;
      })
      .filter((d) => d > now)
      .sort((a, b) => a.getTime() - b.getTime());

    if (todayTimes.length > 0) return todayTimes[0];

    // Nothing left today → use first time tomorrow
    const [h, m] = times[0].split(":").map(Number);
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(h, m, 0, 0);
    return tomorrow;
  }

  if (scheduleType === "weekly") {
    const days = (config.days_of_week as number[]) ?? [1];
    const timeStr = (config.time as string) ?? "09:00";
    const [th, tm] = timeStr.split(":").map(Number);

    // Find the nearest future occurrence across next 8 days
    for (let offset = 0; offset <= 7; offset++) {
      const candidate = new Date(now);
      candidate.setDate(candidate.getDate() + offset);
      candidate.setHours(th, tm, 0, 0);
      if (days.includes(candidate.getDay()) && candidate > now) {
        return candidate;
      }
    }
    // Fallback: one week from now
    return new Date(now.getTime() + 7 * 24 * 60 * 60_000);
  }

  // custom / fallback
  const minutes = (config.every_minutes as number) ?? 60;
  return new Date(now.getTime() + minutes * 60_000);
}

// ── Condition evaluation ──────────────────────────────────────────────────────

function getNestedValue(obj: Record<string, unknown>, path: string): unknown {
  return path.split(".").reduce<unknown>((acc, key) => {
    if (acc && typeof acc === "object") return (acc as Record<string, unknown>)[key];
    return undefined;
  }, obj);
}

function evaluateCondition(record: Record<string, unknown>, cond: {
  field: string;
  rule: string;
  value?: unknown;
}): boolean {
  const raw = record[cond.field];
  const strVal = raw != null ? String(raw) : "";
  const now = Date.now();

  switch (cond.rule) {
    case "equals":      return strVal === String(cond.value ?? "");
    case "not_equals":  return strVal !== String(cond.value ?? "");
    case "contains":    return strVal.toLowerCase().includes(String(cond.value ?? "").toLowerCase());
    case "greater_than": return Number(raw) > Number(cond.value);
    case "less_than":    return Number(raw) < Number(cond.value);
    case "greater_equal": return Number(raw) >= Number(cond.value);
    case "less_equal":    return Number(raw) <= Number(cond.value);
    case "is_empty":     return raw == null || strVal.trim() === "";
    case "is_not_empty": return raw != null && strVal.trim() !== "";
    case "days_until_lte": {
      const diff = (new Date(strVal).getTime() - now) / 86_400_000;
      return diff <= Number(cond.value);
    }
    case "days_until_gte": {
      const diff = (new Date(strVal).getTime() - now) / 86_400_000;
      return diff >= Number(cond.value);
    }
    case "days_since_lte": {
      const diff = (now - new Date(strVal).getTime()) / 86_400_000;
      return diff <= Number(cond.value);
    }
    case "days_since_gte": {
      const diff = (now - new Date(strVal).getTime()) / 86_400_000;
      return diff >= Number(cond.value);
    }
    default: return true;
  }
}

function recordMatchesConditions(
  record: Record<string, unknown>,
  conditions: Array<{ field: string; rule: string; value?: unknown }>,
  operator: string
): boolean {
  if (conditions.length === 0) return true;
  if (operator === "or") {
    return conditions.some((c) => evaluateCondition(record, c));
  }
  return conditions.every((c) => evaluateCondition(record, c));
}

// ── Template interpolation ────────────────────────────────────────────────────

function interpolate(template: string, record: Record<string, unknown>): string {
  const now = new Date();
  const todayIso = now.toISOString().split("T")[0];

  return template.replace(/\{\{([^}]+)\}\}/g, (_, key: string) => {
    key = key.trim();

    if (key === "system.now") return todayIso;

    if (key.startsWith("days_until.")) {
      const field = key.slice("days_until.".length);
      const val = record[field];
      if (val == null) return "?";
      const diff = Math.ceil((new Date(String(val)).getTime() - now.getTime()) / 86_400_000);
      return String(diff);
    }

    if (key.startsWith("days_since.")) {
      const field = key.slice("days_since.".length);
      const val = record[field];
      if (val == null) return "?";
      const diff = Math.floor((now.getTime() - new Date(String(val)).getTime()) / 86_400_000);
      return String(diff);
    }

    return record[key] != null ? String(record[key]) : "";
  });
}

// ── Main handler ──────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  const edgeBase = Deno.env.get("SUPABASE_URL")! + "/functions/v1";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const RESEND_KEY = Deno.env.get("RESEND_API_KEY");

  let reminderId: string;
  try {
    const body = await req.json();
    reminderId = body.reminder_id;
    if (!reminderId) return json({ error: "Missing reminder_id" }, 400);
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  // 1. Fetch the reminder
  const { data: reminder, error: remErr } = await supabase
    .from("reminders")
    .select("*")
    .eq("id", reminderId)
    .maybeSingle();

  if (remErr || !reminder) return json({ error: remErr?.message ?? "Reminder not found" }, 404);

  // 2. Create a run record
  const { data: runRow, error: runErr } = await supabase
    .from("reminder_runs")
    .insert({ reminder_id: reminderId, status: "running" })
    .select()
    .single();

  if (runErr || !runRow) return json({ error: runErr?.message ?? "Could not create run" }, 500);

  const runId: string = runRow.id;
  const now = new Date();

  let recordsFetched = 0;
  let notificationsSent = 0;
  let runError: string | null = null;

  try {
    // 3. Fetch data records
    let records: Array<Record<string, unknown>> = [];

    const dsType: string = reminder.data_source_type ?? "api";
    const dsConfig: Record<string, unknown> = reminder.data_source_config ?? {};

    if (dsType === "api") {
      const url = dsConfig.url as string;
      if (!url) throw new Error("API data source missing url");

      const method = (dsConfig.method as string) ?? "GET";
      const headers = (dsConfig.headers as Record<string, string>) ?? {};

      const apiRes = await fetch(url, {
        method,
        headers,
        body: method === "POST" && dsConfig.body
          ? JSON.stringify(dsConfig.body)
          : undefined,
      });

      if (!apiRes.ok) throw new Error(`API returned ${apiRes.status}`);

      let data: unknown = await apiRes.json();

      const path = dsConfig.response_array_path as string | undefined;
      if (path) {
        for (const key of path.split(".")) {
          data = data && typeof data === "object"
            ? (data as Record<string, unknown>)[key]
            : null;
          if (data == null) break;
        }
      }

      records = Array.isArray(data)
        ? data as Array<Record<string, unknown>>
        : [data as Record<string, unknown>];

    } else if (dsType === "internal") {
      const table = dsConfig.table as string;
      if (!table) throw new Error("Internal data source missing table");

      const cols = (dsConfig.select_columns as string) ?? "*";
      let query = supabase.from(table).select(cols);

      const filters = (dsConfig.filters as Array<{ column: string; operator: string; value: unknown }>) ?? [];
      for (const f of filters) {
        switch (f.operator) {
          case "eq":   query = query.eq(f.column, f.value); break;
          case "neq":  query = query.neq(f.column, f.value); break;
          case "gte":  query = query.gte(f.column, f.value); break;
          case "lte":  query = query.lte(f.column, f.value); break;
          case "like": query = query.like(f.column, String(f.value)); break;
          case "in":   query = query.in(f.column, Array.isArray(f.value) ? f.value : [f.value]); break;
        }
      }

      const { data: rows, error: rowErr } = await query;
      if (rowErr) throw new Error(rowErr.message);
      records = (rows ?? []) as Array<Record<string, unknown>>;

    } else if (dsType === "excel") {
      records = (dsConfig.records as Array<Record<string, unknown>>) ?? [];
    }

    recordsFetched = records.length;

    const conditions = (reminder.conditions ?? []) as Array<{ field: string; rule: string; value?: unknown }>;
    const condOperator: string = reminder.condition_operator ?? "and";
    const hasCondition: boolean = reminder.has_condition ?? false;
    const channels: string[] = reminder.channels ?? ["app"];
    const recipientConfig: Record<string, unknown> = reminder.recipient_config ?? { type: "creator" };
    const recipientType = recipientConfig.type as string;

    // 4. Process matching records
    for (const record of records) {
      try {
        if (hasCondition && !recordMatchesConditions(record, conditions, condOperator)) {
          continue;
        }

        const msgTitle = interpolate(reminder.msg_title_template ?? "", record);
        const msgBody = interpolate(reminder.msg_body_template ?? "", record);

        // Determine recipient user IDs
        const targetUserIds = new Set<string>();
        const broadcastEmails = new Set<string>();

        if (recipientType === "creator") {
          targetUserIds.add(reminder.owner_user_id);

        } else if (recipientType === "mapped_user_id") {
          const field = recipientConfig.user_id_field as string;
          const uid = record[field] as string | undefined;
          if (uid) targetUserIds.add(uid);

        } else if (recipientType === "mapped_email") {
          const field = recipientConfig.email_field as string;
          const email = record[field] as string | undefined;
          if (email) {
            const { data: u } = await supabase
              .from("users")
              .select("id")
              .eq("email", email)
              .maybeSingle();
            if (u?.id) targetUserIds.add(u.id);
          }

        } else if (recipientType === "broadcast_email") {
          const field = recipientConfig.email_field as string;
          const email = record[field] as string | undefined;
          if (email) broadcastEmails.add(email);

        } else if (recipientType === "specific_users") {
          const ids = (recipientConfig.user_ids as string[]) ?? [];
          ids.forEach((id) => targetUserIds.add(id));
        }

        if (recipientConfig.also_notify_creator === true) {
          targetUserIds.add(reminder.owner_user_id);
        }

        // 5. Fetch user tokens / emails for target users
        if (targetUserIds.size > 0) {
          const { data: users } = await supabase
            .from("users")
            .select("id, fcm_token, fcm_token_web, email")
            .in("id", [...targetUserIds]);

          for (const u of users ?? []) {
            if (channels.includes("app")) {
              const tokens = [u.fcm_token, u.fcm_token_web].filter(Boolean) as string[];
              for (const token of tokens) {
                try {
                  await fetch(`${edgeBase}/send-push-notification`, {
                    method: "POST",
                    headers: {
                      "Content-Type": "application/json",
                      Authorization: `Bearer ${serviceKey}`,
                    },
                    body: JSON.stringify({
                      token,
                      title: msgTitle,
                      body: msgBody,
                      data: { type: "reminder", reminder_id: reminderId },
                    }),
                  });
                  notificationsSent++;
                } catch (_) { /* single token failure is non-fatal */ }
              }
            }

            if (channels.includes("email") && u.email && RESEND_KEY) {
              try {
                await fetch("https://api.resend.com/emails", {
                  method: "POST",
                  headers: {
                    Authorization: `Bearer ${RESEND_KEY}`,
                    "Content-Type": "application/json",
                  },
                  body: JSON.stringify({
                    from: "noreply@jalasupport.com",
                    to: u.email,
                    subject: msgTitle,
                    html: `<p>${msgBody}</p><p><small>Reminder: ${reminder.title}</small></p>`,
                  }),
                });
                notificationsSent++;
              } catch (_) { /* email failure is non-fatal */ }
            }
          }
        }

        // broadcast_email targets (no FCM, email only)
        if (broadcastEmails.size > 0 && channels.includes("email") && RESEND_KEY) {
          for (const email of broadcastEmails) {
            try {
              await fetch("https://api.resend.com/emails", {
                method: "POST",
                headers: {
                  Authorization: `Bearer ${RESEND_KEY}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({
                  from: "noreply@jalasupport.com",
                  to: email,
                  subject: msgTitle,
                  html: `<p>${msgBody}</p><p><small>Reminder: ${reminder.title}</small></p>`,
                }),
              });
              notificationsSent++;
            } catch (_) { /* non-fatal */ }
          }
        }

      } catch (recErr) {
        console.error(`Record processing error: ${recErr}`);
      }
    }

    // 6. Update reminder run stats and next_run_at
    const nextRunAt = computeNextRunAt(reminder.schedule_type, reminder.schedule_config ?? {});

    await supabase.from("reminders").update({
      run_count: (reminder.run_count ?? 0) + 1,
      last_run_at: now.toISOString(),
      next_run_at: nextRunAt.toISOString(),
      updated_at: now.toISOString(),
    }).eq("id", reminderId);

    await supabase.from("reminder_runs").update({
      status: "success",
      completed_at: new Date().toISOString(),
      records_fetched: recordsFetched,
      notifications_sent: notificationsSent,
    }).eq("id", runId);

    return json({ ok: true, records_fetched: recordsFetched, notifications_sent: notificationsSent });

  } catch (err) {
    runError = String(err);
    console.error("execute-reminder error:", err);

    await supabase.from("reminder_runs").update({
      status: "failed",
      completed_at: new Date().toISOString(),
      records_fetched: recordsFetched,
      notifications_sent: notificationsSent,
      error_message: runError,
    }).eq("id", runId);

    return json({ ok: false, error: runError }, 500);
  }
});
