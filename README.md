# Dumpen

**Dokumentation:** [vinedrinker.github.io/dumpen](https://vinedrinker.github.io/dumpen/) – start, dokumentation och Docker på en sida med sök.

Dumpen är ett privat bildarkiv för appikoner och temabilder. Det körs som en Cloudflare Worker med bilderna i R2 och inloggning via Cloudflare Access. Det behöver ingen databas, KV eller kö.

## Funktioner

- **Galleri** med översikt, appbilder, temabilder, rutnäts- och listvy, sökning, sortering och filter på app, tema och storlek.
- **Uppladdning** av PNG-bilder i exakt 512 × 512 eller 1254 × 1254 pixlar, högst 12 MB. Storleken läses ur bildens egna bytes, inte ur filnamnet.
- **ZIP-import** av många bilder på en gång, med en granskningslista före uppladdningen.
- **Temabibliotek** där ett helt tema kan laddas ner som ZIP eller raderas.
- **Fasta publika länkar** till varje bild, att klistra in i till exempel en apps logotypfält.
- **Använd i App Launcher:** sätter ett temas ikoner på Cloudflare Access-apparna (valfritt, kräver ett API-token).
- **Import från en äldre bucket:** bilder i en befintlig R2-bucket kan listas och kopieras in utan att originalen ändras.
- Fungerar på mobil och med tangentbord. Inga externa bibliotek eller CDN; allt serveras av Workern.

## Så fungerar det

- **Inloggning:** allt utom `/bilder/*` kräver en giltig Cloudflare Access-JWT. Workern kontrollerar signaturen, utfärdaren, AUD och giltighetstiden själv, även för de statiska sidorna.
- **Publika bilder:** `/bilder/*` är öppet för läsning (`GET` och `HEAD`) och kräver en egen Access-applikation för den sökvägen med policyn *Bypass → Everyone*. Har zonen *Hotlink Protection* påslaget behövs också en konfigurationsregel som stänger av den för `/bilder/`, annars visas bilderna inte på andra sidor.
- **Lagring:** nya bilder sparas under `gallery/` i galleriets bucket:

  ```text
  gallery/apps/<app>/<app>-512x512-<id>.png
  gallery/themes/<tema>/<app>/<tema>-<app>-1254x1254-<id>.png
  ```

  App, tema och storlek sparas också som metadata på varje bild, så listningen behöver aldrig läsa om bilderna.
- **Äldre bucket:** bilder under `apps/` och `uploads/` i den äldre bucketen visas under `/bilder/apps/…` och `/bilder/uploads/…` och kan kopieras till `imported/` i galleriets bucket. Ingenting i den äldre bucketen skrivs över.

## ZIP-import

Arkivet packas upp i webbläsaren med den medföljande `pako`-avkodaren. Varje PNG skickas sedan för sig genom `POST /api/upload`, så servern kontrollerar storlek, filtyp, upplösning och namn precis som vid en vanlig uppladdning.

App och tema läses ur mapp- eller filnamnen:

- `appar/<app>/<app>-512.png` → `gallery/apps/<app>/…`
- `teman/<tema>/<app>/<app>-1254.png` → `gallery/themes/<tema>/<app>/…`
- `<app>-512.png` → `gallery/apps/<app>/…`
- `<app>-<tema>-512.png` → `gallery/themes/<tema>/<app>/…`

Otydliga namn måste rättas i granskningslistan; ingen bild gissas in i fel app. Rader kan väljas bort, och misslyckade rader kan skickas igen utan att sparade bilder dubbleras.

**Gränser:** högst 80 MB per ZIP, 100 bilder och 140 MB uppackad data, högst 12 MB per bild, bara 512 × 512 eller 1254 × 1254. Arkiv med osäkra sökvägar stoppas. Mappar, textfiler och macOS-systemfiler i arkivet hoppas över.

## Lokal utveckling

1. `npm install`
2. Skapa en lokal `.dev.vars` med raden `LOCAL_DEV=true`. Den stänger av Access-kontrollen för `localhost` och får aldrig finnas i produktion.
3. `npm run dev`

## Tester

```bash
npm test && npm run check
```

## Driftsätta på ett eget Cloudflare-konto

Koden innehåller inga kontouppgifter. Där ett eget värde behövs, som domän, resurs-id eller nycklar, står en platshållare (`__NAMN__`). Alla platshållare finns i `cloudflare.example.env`, med en kommentar om var värdet hämtas. Värdena hamnar bara i Cloudflare, aldrig i repot.

**Alternativ 1: deploy från din egen dator.**

1. Kopiera `cloudflare.example.env` till en egen fil utanför repot och fyll i dina värden.
2. Rendera en kopia med dina värden: `node tools/render.mjs <din-fil.env> build [overlay-katalog]`. Verktyget stoppar om ett värde saknas. Filer i overlay-katalogen kopieras ovanpå, till exempel egna bilder.
3. Lägg tokenet för App Launcher-funktionen som hemligheten `WORKERS_API_TOKEN` i Secrets Store (valfritt).
4. Deploya: `npx wrangler deploy --cwd build`.
5. Radera `build/`.

**Alternativ 2: Workers Builds med GitHub-koppling.** Lägg in värdena som *build variables* i Cloudflare (Workers → din Worker → Settings → Build), sätt byggkommandot till `node tools/render.mjs - build` och deploykommandot till `npx wrangler deploy --cwd build`. Bygg bara produktionsgrenen, så skapas inga förhandsversioner.

## Köra med Docker

Dumpen finns som färdig image, `docker.io/driftaegis/dumpen`. Alla inställningar, inloggningssätten och säkerhetskopiering beskrivs i [docker/README.md](docker/README.md). Imagen byggs från repots rot med `docker build -t dumpen .`, och ändringarna listas i [CHANGELOG.md](CHANGELOG.md).

## Bidra

Frågor och idéer tas i [Discussions](https://github.com/VineDrinker/.github/discussions), fel och förslag som issues här. Läs [CONTRIBUTING.md](https://github.com/VineDrinker/.github/blob/main/CONTRIBUTING.md) innan du öppnar en pull request. Säkerhetsproblem rapporteras privat via fliken Security.

## Licens

MIT, se [LICENSE](LICENSE). Den medföljande `pako` har MIT-licens, se [PAKO-LICENSE.txt](PAKO-LICENSE.txt).
