import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const reply = (body, status = 200) => new Response(JSON.stringify(body), {
    status, headers: { ...cors, "Content-Type": "application/json" }
  });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  try {
    const { identifier, password } = await req.json();
    if (typeof identifier !== "string" || typeof password !== "string" || !identifier.trim() || !password) {
      return reply({ error: "Invalid sign-in request" }, 400);
    }
    const url = Deno.env.get("SUPABASE_URL");
    const adminKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!url || !adminKey || !anonKey) return reply({ error: "Authentication service is not configured" }, 500);
    let email = identifier.trim();
    if (!email.includes("@")) {
      const admin = createClient(url, adminKey, { auth: { persistSession: false, autoRefreshToken: false } });
      const { data: profile, error: lookupError } = await admin
        .from("nightfall_profiles").select("id")
        .eq("username_normalized", email.toLowerCase()).maybeSingle();
      if (lookupError || !profile) return reply({ error: "Invalid sign-in details" }, 401);
      const { data: found, error: userError } = await admin.auth.admin.getUserById(profile.id);
      if (userError || !found.user?.email) return reply({ error: "Invalid sign-in details" }, 401);
      email = found.user.email;
    }
    const auth = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data, error } = await auth.auth.signInWithPassword({ email, password });
    if (error || !data.session) return reply({ error: "Invalid sign-in details" }, 401);
    return reply({ access_token: data.session.access_token, refresh_token: data.session.refresh_token });
  } catch {
    return reply({ error: "Invalid sign-in request" }, 400);
  }
});