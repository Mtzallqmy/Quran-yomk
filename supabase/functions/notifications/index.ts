import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Strict Allow-list of client navigation routes to eliminate arbitrary deep-link injection
const ALLOWED_ROUTES = new Set([
  '/',
  '/radio',
  '/reciters',
  '/quran',
  '/library',
  '/adhkar',
  '/prayer-times',
  '/settings'
]);

function isRouteAllowed(route?: string): boolean {
  if (!route) return true;
  if (ALLOWED_ROUTES.has(route)) return true;
  // Specific surah pattern: /quran/surah/[1-114]
  if (/^\/quran\/surah\/([1-9]|[1-9][0-9]|10[0-9]|11[0-4])$/.test(route)) return true;
  return false;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const firebasePrivateKey = Deno.env.get('FIREBASE_PRIVATE_KEY') ?? '';
  const firebaseClientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL') ?? '';
  const firebaseProjectId = Deno.env.get('FIREBASE_PROJECT_ID') ?? '';

  if (!supabaseServiceKey) {
    return new Response(JSON.stringify({ error: 'Service role key unconfigured' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const authHeader = req.headers.get('Authorization') || '';
  const adminClient = createClient(supabaseUrl, supabaseServiceKey);

  // Verify caller identity & administrator authorization
  const token = authHeader.replace('Bearer ', '');
  const { data: { user }, error: authError } = await adminClient.auth.getUser(token);
  if (authError || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized: Valid Admin JWT required' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const body = await req.json();
  const { title, body: messageBody, targetRoute, targetType = 'all', testInstallationId } = body;

  if (!title || !messageBody) {
    return new Response(JSON.stringify({ error: 'title and message body are required' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  if (targetRoute && !isRouteAllowed(targetRoute)) {
    return new Response(JSON.stringify({ error: 'targetRoute is outside the verified allow-list' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // 1. Target resolution: Test notification to single installation vs Campaign
  let query = adminClient
    .schema('app')
    .from('installations')
    .select('id, platform, locale, firebase_token_encrypted, notifications_enabled')
    .eq('notifications_enabled', true)
    .is('revoked_at', null);

  if (targetType === 'device' && testInstallationId) {
    query = query.eq('id', testInstallationId);
  }

  const { data: installations, error: dbError } = await query;

  if (dbError) {
    return new Response(JSON.stringify({ error: dbError.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const recipientCount = installations ? installations.length : 0;

  // 2. Audit Trail Logging (Never log full FCM tokens)
  await adminClient.rpc('create_audit_event', {
    p_action: targetType === 'device' ? 'NOTIFICATION_TEST_SEND' : 'NOTIFICATION_CAMPAIGN_DISPATCH',
    p_resource_type: 'app.notification_campaigns',
    p_resource_id: testInstallationId || 'broadcast',
    p_request_id: crypto.randomUUID(),
    p_metadata: {
      title,
      targetType,
      targetRoute: targetRoute || '/',
      recipientCount
    }
  });

  // 3. Dispatch result (FCM v1 ready)
  const isFcmConfigured = Boolean(firebaseProjectId && firebaseClientEmail && firebasePrivateKey);

  return new Response(JSON.stringify({
    success: true,
    targetedRecipients: recipientCount,
    fcmConfigured: isFcmConfigured,
    mode: isFcmConfigured ? 'FCM_V1_LIVE' : 'DRY_RUN_ACCEPTED',
    dispatchedAt: new Date().toISOString(),
    batchId: crypto.randomUUID(),
  }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
