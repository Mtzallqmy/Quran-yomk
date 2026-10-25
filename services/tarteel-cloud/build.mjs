import {build} from 'esbuild';
await build({entryPoints:['src/index.mjs'],bundle:true,platform:'node',target:'node24',format:'esm',outfile:'dist/index.mjs',banner:{js:"import{createRequire as ___cr}from'module';import{fileURLToPath as ___f}from'url';import{dirname as ___d}from'path';const require=___cr(import.meta.url);const __filename=___f(import.meta.url);const __dirname=___d(__filename);"}});
