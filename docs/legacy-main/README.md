# Preserved main-branch configuration

`admin-next.config.cjs` is the original `apps/admin/next.config.js` from the unrelated historical main application. It is retained here for reference. At its former location Next.js loaded it before the working Tarteel `next.config.ts`, failed under `type: module`, and replaced Tarteel's root route with a legacy `/dashboard` redirect.

The current admin's production configuration remains `apps/admin/next.config.ts`. Legacy `src/app` and component sources remain in the repository; the existing root `app/` directory defines the working routes.

Node components use individual committed lockfiles. The root package intentionally does not declare npm workspaces, which otherwise make `npm ci` in a component require a different root lockfile. Root scripts invoke the production Node components explicitly and fail if a gate is unavailable.
