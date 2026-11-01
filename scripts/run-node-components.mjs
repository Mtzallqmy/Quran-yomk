/** Components retain their independent lockfiles; the Android repo is not an npm workspace. */
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const command = process.argv[2];
if (!['lint', 'typecheck', 'test', 'build'].includes(command)) {
  throw new Error('Expected lint, typecheck, test or build');
}
const components = ['apps/admin', 'services/audio-worker', 'services/radio-engine', 'services/tarteel-cloud'];
for (const component of components) {
  const pkg = JSON.parse(readFileSync(resolve(component, 'package.json'), 'utf8'));
  // Existing components use TypeScript build as their lint/typecheck gate.
  const script = pkg.scripts?.[command] ? command
    : ['lint', 'typecheck'].includes(command) ? (pkg.scripts?.typecheck ? 'typecheck' : 'build') : command;
  if (!pkg.scripts?.[script]) throw new Error(`${component} has no ${command} gate`);
  const result = spawnSync('npm', ['run', script], { cwd: resolve(component), stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
