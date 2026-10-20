# Dumpen — privat bildarkiv

Fristående svenskt gränssnitt för applikationsikoner och temabilder. Inga befintliga objekt skrivs om. Applikationen använder **en Worker med statiska assets**, en befintlig R2-bucket och Cloudflare Access. Ingen D1, KV eller Queue.

## Funktioner

- Översikt, applikationsbilder, temabilder och samlat galleri.
- Rutnäts-/listvy, sökning, sortering, storleks- och formatfilter.
- Kopiera direktlänk för att klistra in i en applikations logotypfält.
- Uppladdning av PNG i exakt 512×512 eller 1254×1254 pixlar, högst 12 MB.
- Bildmetadata härleds från faktiska PNG-bytes och filnamnet.
- Anpassad vy på mobil; tangentbordsstöd; ingen extern frontend-bibliotek eller CDN.

## Befintlig Access-konfiguration och inför bildmigrering

1. Ta bort `<din-host>` från nuvarande publika Access Bypass-destinationer . **Rör inte övriga domäner.**
2. Skapa en *separat* Cloudflare Access self-hosted app med exakt domän `<din-host>`, med lämplig existerande `allow`-policy (t.ex. kontomedlemmar). Bekräfta effektiv Access-beslutsregel.
3. `CF_ACCESS_AUD` i `wrangler.jsonc` är nu konfigurerat till den befintliga skyddade Dumpen-appens AUD-tag. Workern verifierar RS256-JWT för portalen och API:et.
4. Ge Worker endast R2-binding till `<legacy-bucket>` och sätt Custom Domain `<din-host>`. `workers_dev` och `preview_urls` förblir avstängda.
5. Kontrollera att anonym användare blockeras och behörig besökare kan öppna sidan *innan* någon uppladdning görs.

## Lagring

Befintliga bilder i `apps/`, `hotlink-ok/`, `staging/` och `uploads/` ligger kvar orörda. Endast nytt innehåll under `gallery/` syns i portalen under första etappen:

```text
gallery/apps/plex/plex-512x512-a1b2c3d4.png
gallery/themes/midnatt/plex/plex-1254x1254-e5f6a7b8.png
```

Publika bildlänkar byggs under `https://<din-host>/bilder/gallery/...` för nya uppladdningar. Befintliga bilder kan levereras via `https://<din-host>/bilder/apps/...` och `/bilder/uploads/...` utan att flyttas. Cloudflare Access ska ha ett **separat, sökvägsavgränsat Bypass-undantag för exakt `/bilder/*`** innan de publika länkarna tas i bruk. Portalen, `/api/` och övriga vägar förblir skyddade och verifieras av Workern. Bildåtkomst är strikt läsning (GET/HEAD), inte uppladdning. Ta **inte** bort tidigare bildvärd innan alla gamla Access-appbilder har uppdaterats och nya URL:er faktiskt svarar med bildinnehåll. Bilderna ska inte raderas. Därefter kan R2 Custom Domain och oanvända gamla cache-/konfigurationsregler för den tidigare bildvärden tas bort.

## Lokal utveckling

`npm install` (kräver internet vid första installationen), sedan `npm run dev` med en **lokal** `.dev.vars`-fil som innehåller `LOCAL_DEV=true`. Lägg aldrig `LOCAL_DEV` i produktionskonfigurationen. I produktion är `CF_ACCESS_AUD` obligatorisk och Cloudflare Access JWT-signaturen kontrolleras även på statiska sidor.

Frontend kan också öppnas via en lokal statisk server; utan Worker-API visas ett felmeddelande och ett tomt galleri. Inga exempelbilder importeras automatiskt.

## Tester

`npm run check && npm test` – säkerhetstester, PNG-header, R2-sökvägar, uppladdning, galleri och avvisad anonym åtkomst.

## Publiceringsstatus

Portalen är redan publicerad och skyddad med Access. Ny offentlig bildväg `/bilder/*` har lokala tester men får inte tas i bruk förrän sökvägsundantaget är verifierat i Cloudflare Access. Borttagning av tidigare bildvärd görs sist, efter att Cloudflare App Launcher-bildlänkarna har bytts.

## Avveckling av föregående bildvärd

1. Skapa en separat självhostad Cloudflare Access-applikation för `<din-host>/bilder/*` och lägg på en **Bypass → Everyone**-policy. Ändra **inte** den befintliga Dumpen-portalens `Allow`-policy.
   Är *Hotlink Protection* (Scrape Shield) påslaget för zonen: lägg till en konfigurationsregel (Rules → Configuration Rules) för `http.host eq "<din-host>" and starts_with(http.request.uri.path, "/bilder/")` med *Hotlink Protection: Off*. Annars nekas bilderna med 403 (felkod 1011) när en annan sida, till exempel Cloudflare App Launcher, visar dem.
2. Driftsätt den uppdaterade Worker-koden och verifiera anonym `GET` för en befintlig bild under `/bilder/apps/…`, samt 403/Access-inloggning för `/` och `/api/images`.
3. Byt de 12 identifierade App Launcher-bildlänkarna från den gamla värden till `https://<din-host>/bilder/<samma-R2-objektnyckel>`. Kontrollera att varje bild visas.
4. Koppla därefter bort tidigare R2 Custom Domain i `<legacy-bucket>`; den medföljande automatiskt hanterade DNS-posten tas normalt bort samtidigt. Rensa slutligen cache-/konfigurationsregler som enbart avser den gamla bildvärden. Ta inte bort R2-bucketen eller bildobjekt.

Cloudflare-skrivningen av den nya sökvägsregeln och den nya Worker-versionen har blockerats av verktygets säkerhetskontroller och är **inte genomförd**. Detta paket är testat lokalt och förberett, men migreringen är inte produktionsverifierad.

## Nytt i v1.1: ZIP-import av nyproducerade bilder

Ladda upp en ZIP-fil direkt i Dumpen. Arkivet packas upp lokalt i webbläsaren med den medföljande MIT-licensierade pako-avkodaren. PNG-filerna skickas **en och en** genom befintliga skyddade `POST /api/upload`, vilket gör att serverns storleks-, filtyp-, dimensions- och namnkontroller fortsatt gäller. Ingen ny API-token, databas eller extra R2-bucket behövs.

**Automatisk placering** baseras på mappnamn eller filnamn:

- `appar/plex/plex-512.png` → `gallery/apps/plex/…`
- `teman/midnatt/plex/plex-1254.png` → `gallery/themes/midnatt/plex/…`
- `sonarr-512.png` → `gallery/apps/sonarr/…`
- `plex-dark-512.png` → `gallery/themes/dark/plex/…`

Dumpen visar en granskningslista med app-/temafält före uppladdning. Otydliga namn kräver manuell korrigering; ingen bild gissas in i fel app. Välj bort rader som inte ska importeras. Misslyckade rader kan skickas igen utan att redan sparade bilder dubblas.

**Gränser:** 80 MB ZIP, högst 100 PNG-bilder per batch, 140 MB sammanlagd uppackad data, högst 12 MB per PNG, endast 512×512 eller 1254×1254. ZIP-filer med osäkra sökvägar stoppas. ZIP:arna får innehålla mappar, textfiler och macOS-systemfiler (dessa ignoreras). Ingen arkivdata sparas som ZIP i R2.

### Nyproducerade bilder

Ingen konvertering eller bildgenerering görs av Dumpen. Skapa dina nya PNG-bilder separat (i valfritt bildprogram eller med AI-bildgenerering), lägg dem i mapparna ovan och komprimera till ZIP. Därefter laddar du upp allt med en knapp. De gamla bilderna under `apps/`, `uploads/` och `staging/` lämnas orörda.

## Driftsätta på ett eget Cloudflare-konto

Koden innehåller inga kontouppgifter. Där ett eget värde behövs, som domän, resurs-id eller nycklar, står en platshållare (`__NAMN__`). Alla platshållare finns i `cloudflare.example.env`, med en kommentar om var värdet hämtas. Värdena hamnar bara i Cloudflare, aldrig i repot.

**Alternativ 1: deploy från din egen dator (standard).**

1. Kopiera `cloudflare.example.env` till en egen fil utanför repot och fyll i dina värden.
2. Rendera en kopia med dina värden: `node tools/render.mjs <din-fil.env> build [overlay-katalog]`. Verktyget stoppar om ett värde saknas. Filer i overlay-katalogen kopieras ovanpå, till exempel egna bilder.
3. Lägg in hemligheter en gång, antingen var för sig med `npx wrangler secret put <NAMN>` eller alla på en gång från en JSON-fil med `npx wrangler secret bulk <fil.json>`. Radera filen efteråt.
4. Kör databasmigreringarna (se `docs/`) och deploya: `npx wrangler deploy --cwd build`.
5. Radera `build/`. Cloudflare har nu värdena. Vill du ändra något fyller du i filen igen och upprepar steg 2 och 4.

**Alternativ 2: Workers Builds med GitHub-koppling.** Lägg in värdena som *build variables* i Cloudflare (Workers → din Worker → Settings → Build), sätt byggkommandot till `node tools/render.mjs - build` och deploykommandot till `npx wrangler deploy --cwd build`. Bygg bara produktionsgrenen (stäng av bygg för andra grenar), så skapas inga förhandsversioner. Hemligheter läggs in som i alternativ 1.

## Köra med Docker

Dumpen finns som generisk image, `docker.io/driftaegis/dumpen`. Ladda ner `docker-compose.yml`, fyll i `PUBLIC_URL` och välj inloggning med `AUTH_MODE`: `password` (fyll i `ADMIN_PASSWORD`) eller `cloudflare-access` (Access framför sidan, gärna via den medföljande Cloudflare Tunnel-tjänsten). Kör sedan `docker compose up -d`. Bilderna sparas i volymen under `/data`. Ändringar listas i `CHANGELOG.md`.

Alla inställningar beskrivs i [docker/README.md](docker/README.md). Vill du inte ha värdena i compose-filen kan du lägga dem som `NAMN=värde`-rader i `import.env` i datakatalogen och starta om. Containern sparar dem i `settings.env`, som bara containern kan läsa, och raderar importfilen. Imagen byggs från repots rot med `docker build -t dumpen .`.

## Bidra

Frågor och idéer tas i [Discussions](https://github.com/VineDrinker/.github/discussions), fel och förslag som issues här. Läs [CONTRIBUTING.md](https://github.com/VineDrinker/.github/blob/main/CONTRIBUTING.md) innan du öppnar en pull request. Säkerhetsproblem rapporteras privat via fliken Security.

## Licens

MIT, se `LICENSE`. MIT-licensen för den medföljande `pako`-komponenten ligger i `PAKO-LICENSE.txt`.
