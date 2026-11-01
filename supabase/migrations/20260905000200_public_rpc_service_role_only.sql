-- The public/mobile contract is exposed only through the canonical Edge Function.
-- SECURITY DEFINER RPCs must not be callable directly with anon/authenticated keys.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on all functions in schema public to service_role;

-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. Fail closed for
-- future functions created by the migration owner in the public schema.
alter default privileges for role postgres in schema public
  revoke execute on functions from public;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated;
