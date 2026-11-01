# Separate Quran Yutla schema history

These three files are retained byte-for-byte from `main` commit
`73b6efac0018786ef1709105e9c81f58c9aa91c2`. They belong to the separate
Quran Yutla application and are not the Tarteel Flutter 2074 database history.

They must not be replayed alongside Tarteel migrations. The February schema
creates `app.permissions(id, description)`, while March attempts to insert
`app.permissions.key`; mixing them also conflicts with Tarteel metadata/RBAC.
CI caught this before any remote deployment.

The active `supabase/migrations` directory retains the working Tarteel baseline.
Archiving these source files does not modify any database or existing migration
history. Do not reset a remote database or deploy either schema to the other
application's backend. Any future migration of the separate native application
requires its own backup, schema review and isolated validation.
