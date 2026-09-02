const CACHE='tournoi-foot-v38-2';
const STATIC_ASSETS=['./','./index.html','./manifest.webmanifest','./favicon.png','./icon-192.png','./icon-512.png'];

self.addEventListener('install',event=>{
  self.skipWaiting();
  event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(STATIC_ASSETS)));
});

self.addEventListener('activate',event=>{
  event.waitUntil((async()=>{
    const keys=await caches.keys();
    await Promise.all(keys.filter(k=>k.startsWith('tournoi-foot-') && k!==CACHE).map(k=>caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch',event=>{
  const req=event.request;
  if(req.method!=='GET') return;

  const url=new URL(req.url);
  const sameOrigin=url.origin===self.location.origin;

  // IMPORTANT : toutes les données Supabase et toutes les requêtes externes
  // doivent toujours venir du réseau. Aucun cache applicatif.
  if(!sameOrigin){
    event.respondWith(fetch(req,{cache:'no-store'}));
    return;
  }

  // Les navigations prennent toujours la version réseau d'abord.
  if(req.mode==='navigate'){
    event.respondWith(
      fetch(req,{cache:'no-store'})
        .then(resp=>{
          const copy=resp.clone();
          caches.open(CACHE).then(cache=>cache.put('./index.html',copy));
          return resp;
        })
        .catch(()=>caches.match('./index.html'))
    );
    return;
  }

  // sw.js et index.html ne doivent jamais être servis depuis un ancien cache.
  if(url.pathname.endsWith('/sw.js') || url.pathname.endsWith('/index.html')){
    event.respondWith(fetch(req,{cache:'no-store'}));
    return;
  }

  // Cache uniquement des ressources statiques locales.
  event.respondWith(
    caches.match(req).then(cached=>{
      if(cached) return cached;
      return fetch(req).then(resp=>{
        if(resp && resp.ok){
          const copy=resp.clone();
          caches.open(CACHE).then(cache=>cache.put(req,copy));
        }
        return resp;
      });
    })
  );
});
