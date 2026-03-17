// supabase/functions/read-ticket/index.ts
//
// Supabase Edge Function — reads a PCSO EZ2 ticket image
// using Claude API vision. Keeps the Anthropic key server-side.
//
// Deploy: supabase functions deploy read-ticket
// Secret already set from fetch-today: ANTHROPIC_API_KEY

const corsHeaders = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { image, mimeType } = await req.json();
    if (!image || !mimeType) {
      return new Response(
        JSON.stringify({ error: 'Missing image or mimeType' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type':      'application/json',
        'x-api-key':         Deno.env.get('ANTHROPIC_API_KEY')!,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model:      'claude-sonnet-4-20250514',
        max_tokens: 500,
        messages: [{
          role:    'user',
          content: [
            {
              type:   'image',
              source: { type: 'base64', media_type: mimeType, data: image },
            },
            {
              type: 'text',
              text: `PCSO EZ2 ticket. Respond ONLY valid JSON (no markdown):
{"numbers":"XX-YY","date":"Mon DD, YYYY","draw":"2:00 PM or 5:00 PM or 9:00 PM or unknown","type":"straight or rambolito or unknown"}
Numbers must be XX-YY with 01-31. Use null if unclear.`,
            },
          ],
        }],
      }),
    });

    const data   = await res.json();
    const blocks = (data.content ?? []).filter((b: any) => b.type === 'text');
    if (!blocks.length) throw new Error('No text block in response');

    const text  = blocks[blocks.length - 1].text as string;
    const clean = text.replace(/```json|```/g, '').trim();
    const parsed = JSON.parse(clean);

    return new Response(
      JSON.stringify(parsed),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});