# Tarteel optional Neon service — verified 2026-10-23

Resources: project `calm-sky-72162812` (`tarteel`), PostgreSQL 17,
`aws-eu-central-1`. New isolated schema `tarteel_cloud`; existing radio,
Quran, push, Firebase and Supabase data were not migrated or modified.

Development branch `br-still-wildflower-baulgbyz`; production branch
`br-wispy-paper-bahpwe0x`. Both have a completed `tarteelcloud` Node.js 24
Function deployment. Production public API:

`https://br-wispy-paper-bahpwe0x-tarteelcloud.compute.c-8.eu-central-1.aws.neon.tech/`

Actual checks completed:

| Check | Result |
| --- | --- |
| SQL migration applied twice on development branch | PASS |
| Same migration applied to production | PASS |
| SQL insert/read/update with transaction-scoped client role | PASS |
| Other device sees zero backup rows under RLS | PASS |
| RLS rejects cross-device insert | PASS |
| Client DB role cannot read credential hashes | PASS |
| Expected-revision mismatch does not overwrite stored data | PASS |
| Live HTTPS API acceptance on development | PASS |
| Live HTTPS API acceptance on production | PASS |
| Both live scripts clean up test backups and revoke their test keys | PASS |
| Missing/forged/revoked credentials receive HTTP 401 | PASS |
| Location/unknown backup fields receive HTTP 422 | PASS |
| Node security/consent/size/quota tests | 5 PASS |
| Flutter consent/secure key/merge/validation/upload tests | 4 PASS |

The two live runs exercised consent registration, authenticated create/read/update,
isolation between two principals, HTTP 409 conflicts, invalid token rejection,
location rejection, deletion and post-revocation rejection. No credentials or
user payloads were printed by the scripts.

Runtime finding: this account's automatically injected `DATABASE_URL` lacked its
password. A server-only `TARTEEL_DATABASE_URL` override, held in Neon Function
deployment environment, fixed the connection and passed the live tests. Neither
URL/password nor management credential is committed or embedded in Flutter.

The account rejected custom suspend intervals; project settings show 0.25 CU min/max
and the account default `suspend_timeout_seconds=0`. Automatic suspension was not
verified. The optional backup uses installation possession credentials, not account
login or cross-device recovery; the screen explains that uninstalling may lose its
key. Application quotas are persistent across isolates but are not an edge WAF.
