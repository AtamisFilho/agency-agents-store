/* sw.js — service worker do guia. GERADO por gerador/build.py (a versão entra no nome do
   cache: release novo → sw.js muda → browser reinstala → cache antigo é apagado). */
const VER = "v2.3.1";
const CACHE = "agencia-guia-" + VER;
const ASSETS = [
  "./",
  "./guia-especialistas-agencia.html",
  "./manifest.webmanifest",
  "./pwa-icons/icon-192.png",
  "./pwa-icons/icon-512.png",
  "./pwa-icons/icon-maskable-512.png",
  "./pwa-icons/apple-touch-icon.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // Promise.all (não allSettled): se um asset crítico falhar, a instalação do SW
    // FALHA → o browser mantém o SW antigo e o cache bom intacto (ALTO-1 da revisão)
    await Promise.all(ASSETS.map((u) => cache.add(new Request(u, { cache: "reload" }))));
    self.skipWaiting();
  })());
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    // só apaga caches DESTE app — nunca caches de terceiros na mesma origem
    await Promise.all(
      names.filter((n) => n.startsWith("agencia-guia-") && n !== CACHE).map((n) => caches.delete(n))
    );
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;  // checagem de updates (GitHub API) vai direto à rede
  if (req.mode === "navigate") {
    // network-first: online pega o guia novo na hora; offline cai no cache.
    // Só cacheia resposta BOA — 404/5xx transitório do host não substitui a última cópia boa.
    event.respondWith(
      fetch(req).then((res) => {
        if (res.ok && res.type === "basic") {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy));
        }
        return res;
      }).catch(() => caches.match(req).then((r) => r || caches.match(ASSETS[1])))
    );
    return;
  }
  // estáticos (ícones, manifest): cache-first
  event.respondWith(
    caches.match(req).then((hit) => hit || fetch(req).then((res) => {
      if (res.ok) {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy));
      }
      return res;
    }))
  );
});
