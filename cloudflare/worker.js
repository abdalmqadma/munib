const ALLOWED_MODELS = new Set([
  'qwen/qwen3.6-27b',
  'openai/gpt-oss-120b',
]);

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(),
    },
  });
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(),
      });
    }

    if (request.method !== 'POST') {
      return jsonResponse(
        { error: 'Only POST requests are allowed' },
        405,
      );
    }

    if (!env.GROQ_API_KEY) {
      return jsonResponse({ error: 'GROQ_API_KEY secret is not configured' }, 500);
    }

    try {
      const body = await request.json();

      if (body?.type !== 'chat_completion' || !body?.payload) {
        return jsonResponse({ error: 'Invalid request payload' }, 400);
      }

      const payload = body.payload;

      if (typeof payload !== 'object' || Array.isArray(payload)) {
        return jsonResponse({ error: 'payload must be a JSON object' }, 400);
      }

      if (!ALLOWED_MODELS.has(payload.model)) {
        return jsonResponse({ error: 'Requested model is not allowed' }, 400);
      }

      const response = await fetch(
        'https://api.groq.com/openai/v1/chat/completions',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${env.GROQ_API_KEY}`,
          },
          body: JSON.stringify(payload),
        },
      );

      const responseText = await response.text();

      return new Response(responseText, {
        status: response.status,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders(),
        },
      });
    } catch (error) {
      return jsonResponse(
        {
          error: 'Backend error',
          message: error instanceof Error ? error.message : String(error),
        },
        500,
      );
    }
  },
};
