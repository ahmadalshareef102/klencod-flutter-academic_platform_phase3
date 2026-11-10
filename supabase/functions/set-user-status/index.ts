import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// إيقاف/تفعيل حساب: يحدّث profiles.is_active ويحظر المستخدم في Supabase Auth فعليًا
// (فيُلغى تجديد جلسته). للإدارة فقط.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
});

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const url = Deno.env.get('SUPABASE_URL');
  const anon = Deno.env.get('SUPABASE_ANON_KEY');
  const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anon || !service) return json({ error: 'Server configuration missing' }, 500);
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Unauthorized' }, 401);
  const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) return json({ error: 'Unauthorized' }, 401);
  const adminClient = createClient(url, service);
  const { data: actor } = await adminClient.from('profiles').select('role,is_active').eq('id', user.id).maybeSingle();
  if (!actor || actor.role !== 'admin' || actor.is_active !== true) return json({ error: 'Admin role required' }, 403);

  let payload: Record<string, unknown>;
  try { payload = await req.json(); } catch { return json({ error: 'Invalid JSON body' }, 400); }
  const targetId = String(payload.user_id ?? '');
  const isActive = payload.is_active;
  if (!/^[0-9a-f-]{36}$/i.test(targetId) || typeof isActive !== 'boolean') {
    return json({ error: 'بيانات غير صحيحة.' }, 400);
  }
  if (targetId === user.id) return json({ error: 'لا يمكنك إيقاف حسابك بنفسك.' }, 400);

  const { error: profileError } = await adminClient.from('profiles').update({ is_active: isActive }).eq('id', targetId);
  if (profileError) return json({ error: `تعذر تحديث الحساب: ${profileError.message}` }, 500);
  // حظر طويل جدًا عند الإيقاف، ورفع الحظر عند التفعيل.
  const { error: banError } = await adminClient.auth.admin.updateUserById(targetId, { ban_duration: isActive ? 'none' : '876000h' });
  if (banError) {
    // أعد الحالة السابقة كي لا يبقى الوضع متناقضًا.
    await adminClient.from('profiles').update({ is_active: !isActive }).eq('id', targetId);
    return json({ error: `تعذر تحديث حالة الدخول: ${banError.message}` }, 500);
  }
  return json({ id: targetId, is_active: isActive });
});
