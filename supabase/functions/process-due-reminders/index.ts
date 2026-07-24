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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const now = new Date().toISOString();

  // A reminder that has never run has next_run_at = NULL (it's only ever set
  // once execute-reminder finishes a run). `.lte()` alone never matches NULL,
  // so newly created reminders would otherwise sit forever without ever
  // firing their first run — treat NULL as "due now" too.
  const { data: dueReminders, error } = await supabase
    .from("reminders")
    .select("id")
    .eq("is_active", true)
    .or(`next_run_at.is.null,next_run_at.lte.${now}`);

  if (error) return json({ error: error.message }, 500);
  if (!dueReminders || dueReminders.length === 0) {
    return json({ ok: true, processed: 0 });
  }

  const edgeBase = Deno.env.get("SUPABASE_URL") + "/functions/v1";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const results = await Promise.allSettled(
    dueReminders.map((r: { id: string }) =>
      fetch(`${edgeBase}/execute-reminder`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({ reminder_id: r.id }),
      })
    )
  );

  return json({
    ok: true,
    processed: dueReminders.length,
    results: results.map((r) => r.status),
  });
});
