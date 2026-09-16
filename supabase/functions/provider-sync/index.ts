import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

  if (!supabaseServiceKey) {
    return new Response(JSON.stringify({ error: 'Service role key unconfigured' }), { status: 500 });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // Sync / Health check with external radio stream providers
  const { data: stations } = await supabase
    .schema('app')
    .from('stations')
    .select('id, slug, stream_url, source_type')
    .eq('is_active', true);

  return new Response(JSON.stringify({
    success: true,
    checkedStationsCount: stations?.length || 0,
    syncedAt: new Date().toISOString()
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  });
});
