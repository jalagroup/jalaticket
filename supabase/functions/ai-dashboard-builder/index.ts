import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const MODEL = "claude-sonnet-4-6";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { prompt, data, language, department_id } = await req.json();

    const isArabic = language === "ar";
    const langNote = isArabic
      ? "Respond with all labels, titles, and text IN ARABIC."
      : "Respond with all labels, titles, and text IN ENGLISH.";

    const systemPrompt = `You are a business intelligence assistant that builds dashboards from ticket support data.
You MUST return ONLY valid JSON — no markdown, no explanation, no code fences.
${langNote}

The JSON structure must be exactly:
{
  "dashboard_title": "string",
  "kpis": [
    { "label": "string", "value": "string", "subtitle": "string", "change": "string" }
  ],
  "charts": [
    {
      "type": "bar" | "pie" | "line" | "area" | "horizontal_bar",
      "title": "string",
      "x_labels": ["string"],
      "series": [
        { "label": "string", "data": [number] }
      ]
    }
  ],
  "tables": [
    {
      "title": "string",
      "columns": ["string"],
      "rows": [["string"]]
    }
  ]
}

Rules:
- kpis: 2–6 items. value is always a formatted string (e.g. "142", "63%", "4.2 days").
- charts: 1–4 items.
- tables: 0–2 items.
- change field: use "+N%" for increase, "-N%" for decrease, or "" if not applicable.
- Keep data[] arrays short (max 12 items for line/bar).
- Never include raw IDs or UUIDs in output.

CRITICAL pie chart format — x_labels holds the SLICE NAMES, series has exactly ONE item:
CORRECT:
{
  "type": "pie",
  "title": "Tickets by Status",
  "x_labels": ["Open", "In Progress", "Closed"],
  "series": [{ "label": "Status", "data": [30, 45, 25] }]
}
WRONG (never do this):
{
  "type": "pie",
  "x_labels": [],
  "series": [
    { "label": "Open", "data": [30] },
    { "label": "Closed", "data": [25] }
  ]
}

For bar/line/area charts: x_labels = category names, each series = one data set with data[] matching x_labels length.
Use "area" for filled trend charts (time-series, cumulative values).
Use "horizontal_bar" for ranked comparisons (e.g. top departments by ticket count).`;

    const userMessage = `Ticket data summary (aggregated, not raw records):
${JSON.stringify(data, null, 2)}

Dashboard request:
${prompt}`;

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 2048,
        system: systemPrompt,
        messages: [{ role: "user", content: userMessage }],
      }),
    });

    if (!response.ok) {
      const err = await response.text();
      return new Response(JSON.stringify({ error: err }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const anthropicBody = await response.json();
    const rawText: string = anthropicBody.content[0].text.trim();

    // Strip accidental markdown fences
    const cleaned = rawText
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/\s*```$/i, "")
      .trim();

    const dashboard = JSON.parse(cleaned);

    return new Response(JSON.stringify(dashboard), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
