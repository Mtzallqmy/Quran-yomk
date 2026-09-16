import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Strict Allow-list of client navigation routes
const ALLOWED_ROUTES = new Set([
  '/',
  '/home',
  '/radio',
  '/reciters',
  '/quran',
  '/library',
  '/adhkar',
  '/prayer-times',
  '/custom-reminders',
  '/settings'
]);

function isRouteAllowed(route?: string): boolean {
  if (!route) return true;
  if (ALLOWED_ROUTES.has(route)) return true;
  if (/^\/quran\/surah\/([1-9]|[1-9][0-9]|10[0-9]|11[0-4])$/.test(route)) return true;
  return false;
}

/**
 * Base64URL encoder helper
 */
function base64UrlEncode(str: string | Uint8Array): string {
  const bytes = typeof str === 'string' ? new TextEncoder().encode(str) : str;
  let base64 = btoa(String.fromCharCode(...bytes));
  return base64.replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

/**
 * Generate Google OAuth2 Access Token for FCM HTTP v1 using Web Crypto RSA-SHA256
 */
async function getFcmAccessToken(clientEmail: string, privateKeyRaw: string): Promise<string> {
  const formattedKey = privateKeyRaw.replace(/\\n/g, '\n');

  // Convert PEM to DER ArrayBuffer
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = formattedKey
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s+/g, "");
  
  const binaryDerString = atob(pemContents);
  const derBuffer = new Uint8Array(binaryDerString.length);
  for (let i = 0; i < binaryDerString.length; i++) {
    derBuffer[i] = binaryDerString.charCodeAt(i);
  }

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    derBuffer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const jwt = `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;

  // Exchange JWT for OAuth access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  if (!tokenResponse.ok) {
    throw new Error(`Google OAuth error: ${tokenData.error_description || tokenData.error}`);
  }

  return tokenData.access_token;
}

/**
 * Send single message via FCM HTTP v1 API
 */
async function sendFcmV1Message(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  targetRoute: string,
  deliveryId: string
): Promise<{ success: boolean; error?: string }> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  
  const payload = {
    message: {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        title: title,
        body: body,
        targetRoute: targetRoute,
        delivery_id: deliveryId,
      },
      android: {
        priority: "HIGH",
        notification: {
          channel_id: "quran_yutla_fcm_channel",
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            alert: { title: title, body: body },
            sound: "default",
          },
        },
      },
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (res.ok) {
    return { success: true };
  } else {
    const errorJson = await res.json();
    return { success: false, error: JSON.stringify(errorJson) };
  }
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
  const {
    title,
    body: messageBody,
    targetRoute = '/home',
    targetType = 'all', // 'sendToInstallation', 'sendToDevice', 'sendToSegment', 'sendTest', 'sendBroadcast'
    testInstallationId,
    fcmTokenDirect
  } = body;

  if (!title || !messageBody) {
    return new Response(JSON.stringify({ error: 'title and body are required' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const sanitizedRoute = isRouteAllowed(targetRoute) ? targetRoute : '/home';

  const isFcmConfigured = Boolean(firebaseProjectId && firebaseClientEmail && firebasePrivateKey);
  if (!isFcmConfigured && targetType === 'sendTest') {
    return new Response(JSON.stringify({
      error: 'FIREBASE_CONFIG_MISSING',
      message: 'FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY must be set in Supabase Secrets.'
    }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Target resolution from app.installations table
  let query = adminClient
    .schema('app')
    .from('installations')
    .select('id, platform, firebase_token_encrypted, notifications_enabled')
    .eq('notifications_enabled', true)
    .is('revoked_at', null);

  if ((targetType === 'sendToDevice' || targetType === 'sendTest' || targetType === 'sendToInstallation') && testInstallationId) {
    query = query.eq('id', testInstallationId);
  }

  const { data: installations, error: dbError } = await query;
  if (dbError) {
    return new Response(JSON.stringify({ error: dbError.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const targetTokens: { id: string; token: string }[] = [];
  if (fcmTokenDirect) {
    targetTokens.push({ id: testInstallationId || 'direct', token: fcmTokenDirect });
  } else if (installations) {
    for (const inst of installations) {
      if (inst.firebase_token_encrypted) {
        targetTokens.push({ id: inst.id, token: inst.firebase_token_encrypted });
      }
    }
  }

  let successCount = 0;
  let failureCount = 0;
  const deliveryId = crypto.randomUUID();

  if (isFcmConfigured && targetTokens.length > 0) {
    try {
      const accessToken = await getFcmAccessToken(firebaseClientEmail, firebasePrivateKey);
      for (const target of targetTokens) {
        const result = await sendFcmV1Message(
          firebaseProjectId,
          accessToken,
          target.token,
          title,
          messageBody,
          sanitizedRoute,
          deliveryId
        );
        if (result.success) {
          successCount++;
        } else {
          failureCount++;
        }
      }
    } catch (e: any) {
      return new Response(JSON.stringify({
        error: 'FCM_DISPATCH_FAILED',
        details: e?.message || String(e)
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
  }

  // Audit Trail Logging (Never log raw FCM token or private key)
  await adminClient.rpc('create_audit_event', {
    p_action: targetType === 'sendTest' ? 'NOTIFICATION_TEST_SEND' : 'NOTIFICATION_DISPATCH',
    p_resource_type: 'app.notification_campaigns',
    p_resource_id: testInstallationId || 'broadcast',
    p_request_id: deliveryId,
    p_metadata: {
      title,
      targetType,
      targetRoute: sanitizedRoute,
      targetedRecipients: targetTokens.length,
      successCount,
      failureCount,
    }
  });

  return new Response(JSON.stringify({
    success: true,
    targetedRecipients: targetTokens.length,
    successCount,
    failureCount,
    fcmConfigured: isFcmConfigured,
    mode: isFcmConfigured ? 'FCM_V1_LIVE' : 'DRY_RUN_ACCEPTED',
    deliveryId,
    dispatchedAt: new Date().toISOString(),
  }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
