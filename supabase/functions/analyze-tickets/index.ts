import "@supabase/functions-js/edge-runtime.d.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface Ticket {
  id: string;
  title: string;
  description?: string;
  problem_title?: string;
  place_name?: string;
  department_name?: string;
  status: string;
  created_at: string;
  resolved_at?: string;
}

interface AnalysisRequest {
  tickets: Ticket[];
  place_filter?: string;
  department_filter?: string;
  language?: "en" | "ar";
}

interface AnalysisResponse {
  top_problem_places: Array<{ place: string; count: number; common_issues: string[] }>;
  recurring_issues: Array<{ issue: string; frequency: number; affected_places: string[] }>;
  root_causes: Array<{ cause: string; evidence: string[] }>;
  replacement_recommendations: Array<{ item: string; priority: "high" | "medium" | "low"; reason: string }>;
  prevention_suggestions: string[];
  smart_title_suggestions: string[];
  summary: string;
}

function buildPrompt(req: AnalysisRequest): string {
  const { tickets, place_filter, department_filter, language = "en" } = req;
  const isArabic = language === "ar";

  const statsMap: Record<string, { count: number; statuses: string[]; titles: string[] }> = {};
  for (const t of tickets) {
    const place = t.place_name ?? "Unknown";
    if (!statsMap[place]) statsMap[place] = { count: 0, statuses: [], titles: [] };
    statsMap[place].count++;
    statsMap[place].statuses.push(t.status);
    if (t.problem_title) statsMap[place].titles.push(t.problem_title);
  }

  const placeStats = Object.entries(statsMap)
    .sort((a, b) => b[1].count - a[1].count)
    .slice(0, 10)
    .map(([place, s]) => `- ${place}: ${s.count} tickets, statuses: [${[...new Set(s.statuses)].join(", ")}]`)
    .join("\n");

  const ticketSample = tickets
    .slice(0, 50)
    .map((t) =>
      `ID:${t.id} | Place:${t.place_name ?? "-"} | Dept:${t.department_name ?? "-"} | Status:${t.status} | Problem:"${t.problem_title ?? t.title}" | Desc:"${(t.description ?? "").slice(0, 120)}"`
    )
    .join("\n");

  const filters = [
    place_filter ? `Place filter: ${place_filter}` : null,
    department_filter ? `Department filter: ${department_filter}` : null,
  ]
    .filter(Boolean)
    .join(", ");

  const lang = isArabic ? "Arabic" : "English";
  const rtlNote = isArabic ? " Write all text values in Arabic only. Use right-to-left friendly phrasing." : "";

  return `You are a facility maintenance analyst. Analyze the following support ticket data and return a JSON object matching the schema exactly. Respond entirely in ${lang}.${rtlNote}

${filters ? `Filters applied: ${filters}\n` : ""}
Total tickets: ${tickets.length}

--- Place Summary ---
${placeStats}

--- Ticket Sample (up to 50) ---
${ticketSample}

Return ONLY valid JSON with this exact structure (no markdown, no explanation):
{
  "top_problem_places": [{"place": string, "count": number, "common_issues": [string]}],
  "recurring_issues": [{"issue": string, "frequency": number, "affected_places": [string]}],
  "root_causes": [{"cause": string, "evidence": [string]}],
  "replacement_recommendations": [{"item": string, "priority": "high"|"medium"|"low", "reason": string}],
  "prevention_suggestions": [string],
  "smart_title_suggestions": [string],
  "summary": string
}

Rules:
- top_problem_places: top 5 places by ticket volume with their most common issue categories
- recurring_issues: issues appearing 3+ times across tickets, sorted by frequency descending
- root_causes: inferred systemic causes (e.g., aging equipment, lack of preventive maintenance)
- replacement_recommendations: specific equipment or systems that should be replaced, with priority
- prevention_suggestions: 5-7 actionable prevention steps
- smart_title_suggestions: 5 concise ticket title templates for the most common issues found
- summary: 2-3 sentence executive summary
- priority values must remain exactly: "high", "medium", or "low" (English, regardless of language)`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  // Temporary debug: GET /analyze-tickets → list available models
  if (req.method === "GET") {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    const modelsRes = await fetch("https://api.anthropic.com/v1/models", {
      headers: { "x-api-key": apiKey!, "anthropic-version": "2023-06-01" },
    });
    const models = await modelsRes.json();
    return new Response(JSON.stringify(models), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return new Response(JSON.stringify({ error: "ANTHROPIC_API_KEY not configured" }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  let body: AnalysisRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  if (!Array.isArray(body.tickets) || body.tickets.length === 0) {
    return new Response(JSON.stringify({ error: "tickets array is required and must not be empty" }), {
      status: 400,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const prompt = buildPrompt(body);

  const claudeResponse = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 4096,
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
    }),
  });

  if (!claudeResponse.ok) {
    const err = await claudeResponse.text();
    console.error("Claude API error:", claudeResponse.status, err);
    return new Response(
      JSON.stringify({ error: "Claude API error", status: claudeResponse.status, details: err }),
      { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }

  const claudeData = await claudeResponse.json();

  const textBlock = claudeData.content?.find((b: { type: string }) => b.type === "text");
  if (!textBlock) {
    return new Response(JSON.stringify({ error: "No text response from Claude" }), {
      status: 502,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  let analysis: AnalysisResponse;
  try {
    const raw = textBlock.text.trim();
    const jsonText = raw.startsWith("```")
      ? raw.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim()
      : raw;
    analysis = JSON.parse(jsonText);
  } catch {
    return new Response(
      JSON.stringify({ error: "Claude returned invalid JSON", raw: textBlock.text }),
      { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }

  return new Response(JSON.stringify(analysis), {
    status: 200,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
});
