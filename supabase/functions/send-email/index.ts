// Generic transactional email sender via Resend, and the single place
// template rendering happens. execute-reminder and notify-form-submission
// route their emails through this function (instead of calling Resend
// directly) so every outgoing email automatically gets the same
// System-Admin-designed template from the `email_templates` table.
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status, headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

type EmailBlock = {
  type: string;
  text?: string;
  image_url?: string;
  button_url?: string;
  font_size?: number;
  bold?: boolean;
  text_align?: string;
  text_color?: string;
  spacer_height?: number;
};

function substituteTokens(source: string, tokens: Record<string, string>): string {
  return source.replace(/\{\{\s*([a-zA-Z_]+)\s*\}\}/g, (_, key: string) => tokens[key] ?? "");
}

function renderBlocksToHtml(blocks: EmailBlock[], tokens: Record<string, string>): string {
  const rows = blocks.map((b) => {
    const text = b.text ? substituteTokens(b.text, tokens) : "";
    switch (b.type) {
      case "logo":
        return b.image_url
          ? `<tr><td style="padding:12px 24px;text-align:center;"><img src="${b.image_url}" alt="logo" style="max-height:60px;"/></td></tr>`
          : "";
      case "heading":
        return `<tr><td style="padding:8px 24px;text-align:${b.text_align ?? "right"};">` +
          `<h2 style="margin:0;font-size:${b.font_size ?? 20}px;color:${b.text_color ?? "#1A1A1A"};font-weight:${b.bold === false ? 400 : 700};">${text}</h2></td></tr>`;
      case "text":
        return `<tr><td style="padding:8px 24px;text-align:${b.text_align ?? "right"};">` +
          `<p style="margin:0;font-size:${b.font_size ?? 16}px;color:${b.text_color ?? "#1A1A1A"};font-weight:${b.bold ? 700 : 400};">${text.replace(/\n/g, "<br/>")}</p></td></tr>`;
      case "button":
        return `<tr><td style="padding:16px 24px;text-align:${b.text_align ?? "center"};">` +
          `<a href="${b.button_url ?? "#"}" style="display:inline-block;background:#f16936;color:#ffffff;padding:10px 24px;border-radius:6px;text-decoration:none;font-weight:700;">${text}</a></td></tr>`;
      case "divider":
        return `<tr><td style="padding:8px 24px;"><hr style="border:none;border-top:1px solid #e5e5e5;"/></td></tr>`;
      case "spacer":
        return `<tr><td style="height:${b.spacer_height ?? 24}px;"></td></tr>`;
      case "footer":
        return `<tr><td style="padding:16px 24px;text-align:${b.text_align ?? "center"};">` +
          `<p style="margin:0;font-size:12px;color:#999999;">${text}</p></td></tr>`;
      default:
        return "";
    }
  }).join("");

  return `<table role="presentation" dir="rtl" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;margin:0 auto;background:#ffffff;font-family:Tahoma,Arial,sans-serif;">${rows}</table>`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const {
      to, subject, html, text,
      title, message, recipient_name,
      preview_mode, preview_blocks, preview_html_source,
    } = await req.json();

    if (!to || !subject) {
      return json({ error: "Missing required fields: to, subject" }, 400);
    }

    const RESEND_KEY = Deno.env.get("RESEND_API_KEY");
    if (!RESEND_KEY) {
      return json({ error: "RESEND_API_KEY secret not configured" }, 500);
    }

    let renderedHtml: string;

    if (html && title == null && message == null) {
      // Explicit raw HTML with no structured content — used as-is (test
      // curls, or any future caller that wants full control).
      renderedHtml = html;
    } else {
      const tokens: Record<string, string> = {
        title: title ?? "",
        message: (message ?? "").toString().replace(/\n/g, "<br/>"),
        recipient_name: recipient_name ?? "",
        app_name: "دعم جالا",
      };

      let mode = preview_mode as string | undefined;
      let blocks = preview_blocks as EmailBlock[] | undefined;
      let htmlSource = preview_html_source as string | undefined;

      if (!mode) {
        const supabase = createClient(
          Deno.env.get("SUPABASE_URL")!,
          Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
        );
        const { data: tmpl } = await supabase
          .from("email_templates")
          .select("*")
          .order("updated_at", { ascending: false })
          .limit(1)
          .maybeSingle();
        if (tmpl) {
          mode = tmpl.mode;
          blocks = tmpl.blocks;
          htmlSource = tmpl.html_source;
        }
      }

      if (mode === "html" && htmlSource) {
        renderedHtml = substituteTokens(htmlSource, tokens);
      } else if (mode === "visual" && blocks && blocks.length > 0) {
        renderedHtml = renderBlocksToHtml(blocks, tokens);
      } else {
        // No template configured — original bare fallback, RTL by default
        // since this app's audience is primarily Arabic-speaking.
        renderedHtml = html ?? `<p dir="rtl" style="text-align:right;font-family:Tahoma,Arial,sans-serif;">${tokens.message || (text ?? "").toString().replace(/\n/g, "<br/>")}</p>`;
      }
    }

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "Jala <noreply@support.jala.ps>",
        to, subject,
        html: renderedHtml,
      }),
    });

    if (!res.ok) {
      const errText = await res.text();
      console.error(`Resend error (${res.status}): ${errText}`);
      return json({ ok: false, error: `Resend error (${res.status}): ${errText}` }, res.status);
    }

    const result = await res.json();
    return json({ ok: true, result });
  } catch (e) {
    console.error("send-email error:", e);
    return json({ error: String(e) }, 500);
  }
});
