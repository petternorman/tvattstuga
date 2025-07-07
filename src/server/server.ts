import { Application, Router, send, config } from "./deps.ts";
import { login } from "./login.ts";
import { scrape } from "./scrape.ts";

const env = config();
const USER = env.USER;
const PASS = env.PASS;

const router = new Router();
router.get("/api/tvatt", async (ctx) => {
  const cookie = await login(USER, PASS);
  const data = await scrape(cookie);
  ctx.response.body = data;
});

// Serve static files from build
router.get("/build/(.*)", async (ctx) => {
  await send(ctx, ctx.request.url.pathname, {
    root: `${Deno.cwd()}`,
  });
});

// Serve index.html for all other routes (SPA routing)
router.get("/(.*)", async (ctx) => {
  await send(ctx, "index.html", {
    root: `${Deno.cwd()}/build`,
  });
});

const app = new Application();
app.use(router.routes());
app.use(router.allowedMethods());

const port = Number(env.PORT) || 3000;
console.log(`Running server on http://localhost:${port}`);
await app.listen({ port });
