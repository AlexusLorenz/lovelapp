// Lovel – Push-Benachrichtigungen verschicken (Web Push, VAPID).
//
// Wird von der Datenbank (pg_net) angestoßen, sobald etwas im Ausgangskorb
// liegt, und alle 5 Minuten als Nachzügler-Prüfung (pg_cron). Der Aufruf
// braucht keine Anmeldung: Er verschickt nur, was der Server selbst in den
// Ausgangskorb gelegt hat. Die VAPID-Schlüssel erzeugt die Funktion beim
// ersten Lauf selbst und speichert sie in der Datenbank (private.push_config).
//
// Deploy mit verify_jwt = false.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

type Sub = { endpoint: string; keys: { p256dh: string; auth: string } };
type Item = {
  id: number;
  title: string;
  body: string;
  url: string;
  tag: string;
  subscriptions: Sub[];
};

async function vapidKeys(): Promise<{ public: string; private: string }> {
  const { data, error } = await supabase.rpc("push_get_config");
  if (error) throw error;
  if (data?.public && data?.private) return data;
  const keys = webpush.generateVAPIDKeys();
  const { data: stored, error: e2 } = await supabase.rpc("push_init_keys", {
    p_public: keys.publicKey,
    p_private: keys.privateKey,
  });
  if (e2) throw e2;
  return stored;
}

let running = false;

async function run(): Promise<{ sent: number; gone: number }> {
  const keys = await vapidKeys();
  webpush.setVapidDetails("mailto:push@lovel.app", keys.public, keys.private);
  let sentTotal = 0;
  let goneTotal = 0;
  // Abarbeiten, bis nichts mehr offen ist (max. 5 Durchgänge).
  for (let pass = 0; pass < 5; pass++) {
    const { data, error } = await supabase.rpc("push_claim", { p_limit: 200 });
    if (error) throw error;
    const items = (data ?? []) as Item[];
    if (items.length === 0) break;
    const sent: number[] = [];
    const gone: string[] = [];
    await Promise.all(items.map(async (item) => {
      const payload = JSON.stringify({
        title: item.title,
        body: item.body,
        url: item.url,
        tag: item.tag,
      });
      let delivered = item.subscriptions.length === 0;
      await Promise.all(item.subscriptions.map(async (sub) => {
        try {
          await webpush.sendNotification(sub, payload, {
            TTL: 60 * 60 * 24,
            urgency: "normal",
          });
          delivered = true;
        } catch (e) {
          const status = (e as { statusCode?: number }).statusCode;
          // 404/410: Abo gibt es nicht mehr → löschen.
          if (status === 404 || status === 410) {
            gone.push(sub.endpoint);
            delivered = true;
          } else {
            console.error("push failed", status);
          }
        }
      }));
      if (delivered) sent.push(item.id);
    }));
    const { error: e3 } = await supabase.rpc("push_done", {
      p_sent: sent,
      p_gone: gone,
    });
    if (e3) throw e3;
    sentTotal += sent.length;
    goneTotal += gone.length;
  }
  return { sent: sentTotal, gone: goneTotal };
}

Deno.serve(async (req) => {
  if (req.method !== "POST" && req.method !== "GET") {
    return new Response("method", { status: 405 });
  }
  if (running) return Response.json({ busy: true });
  running = true;
  try {
    return Response.json(await run());
  } catch (e) {
    console.error(e);
    return Response.json({ error: "failed" }, { status: 500 });
  } finally {
    running = false;
  }
});
