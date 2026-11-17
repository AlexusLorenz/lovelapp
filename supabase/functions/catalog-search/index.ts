// Suche in externen Datenbanken für Lieblingsspiele (RAWG) und
// Lieblingskünstler:innen (Spotify). Die Schlüssel bleiben hier auf dem Server.
//
// Secrets (Supabase-Dashboard → Edge Functions → Secrets):
//   RAWG_API_KEY           – kostenloser Schlüssel von https://rawg.io/apidocs
//   SPOTIFY_CLIENT_ID      – aus dem Spotify-Developer-Dashboard
//   SPOTIFY_CLIENT_SECRET  – ebenda (nur hier, nie im Client!)
//
// Aufruf (nur angemeldet, JWT wird von Supabase geprüft):
//   POST { "type": "games" | "artists", "q": "zelda" }
//   → { "items": [ { "id", "name", "cover" | "image" } ] }

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// Nur Bilder von den erlaubten CDNs durchreichen (DB prüft das auch).
const rawgImage = /^https:\/\/media\.rawg\.io\/media\/[A-Za-z0-9_./-]+$/;
const spotifyImage = /^https:\/\/i\.scdn\.co\/image\/[A-Za-z0-9]+$/;

/** Verkleinertes Bild statt Original (spart Datenvolumen). */
function rawgCrop(url: string | null | undefined): string | null {
  if (!url || !rawgImage.test(url)) return null;
  return url.replace("/media/games/", "/media/crop/600/400/games/")
    .replace("/media/screenshots/", "/media/crop/600/400/screenshots/");
}

async function searchGames(q: string): Promise<Response> {
  const key = Deno.env.get("RAWG_API_KEY");
  if (!key) return json({ error: "not_configured" }, 503);
  const url = new URL("https://api.rawg.io/api/games");
  url.searchParams.set("key", key);
  url.searchParams.set("search", q);
  url.searchParams.set("page_size", "12");
  url.searchParams.set("search_precise", "true");
  const res = await fetch(url);
  if (!res.ok) return json({ error: "upstream" }, 502);
  const data = await res.json();
  const items = (data.results ?? []).map((g: Record<string, unknown>) => ({
    id: g.id,
    name: g.name,
    cover: rawgCrop(g.background_image as string | null),
  }));
  return json({ items });
}

let spotifyToken: { value: string; expiresAt: number } | null = null;

async function spotifyAppToken(): Promise<string | null> {
  if (spotifyToken && spotifyToken.expiresAt > Date.now() + 30_000) {
    return spotifyToken.value;
  }
  const id = Deno.env.get("SPOTIFY_CLIENT_ID");
  const secret = Deno.env.get("SPOTIFY_CLIENT_SECRET");
  if (!id || !secret) return null;
  const res = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Authorization: "Basic " + btoa(`${id}:${secret}`),
    },
    body: "grant_type=client_credentials",
  });
  if (!res.ok) return null;
  const data = await res.json();
  spotifyToken = {
    value: data.access_token,
    expiresAt: Date.now() + data.expires_in * 1000,
  };
  return spotifyToken.value;
}

async function searchArtists(q: string): Promise<Response> {
  const token = await spotifyAppToken();
  if (!token) return json({ error: "not_configured" }, 503);
  const url = new URL("https://api.spotify.com/v1/search");
  url.searchParams.set("q", q);
  url.searchParams.set("type", "artist");
  url.searchParams.set("limit", "10"); // Maximum im Development Mode
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return json({ error: "upstream" }, 502);
  const data = await res.json();
  const items = (data.artists?.items ?? []).map(
    (a: { id: string; name: string; images?: { url: string; width?: number }[] }) => {
      const images = [...(a.images ?? [])].sort((x, y) =>
        (x.width ?? 0) - (y.width ?? 0)
      );
      const pick = images.find((i) => (i.width ?? 0) >= 160) ??
        images[images.length - 1];
      const image = pick && spotifyImage.test(pick.url) ? pick.url : null;
      return { id: a.id, name: a.name, image };
    },
  );
  return json({ items });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method" }, 405);

  let body: { type?: string; q?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  const q = (body.q ?? "").trim().slice(0, 80);
  if (q.length < 2) return json({ items: [] });

  try {
    if (body.type === "games") return await searchGames(q);
    if (body.type === "artists") return await searchArtists(q);
    return json({ error: "bad_type" }, 400);
  } catch (_) {
    return json({ error: "upstream" }, 502);
  }
});
