# Dumpen

Dumpen är ett privat bildarkiv för appikoner och temabilder. Du laddar upp PNG-bilder (512 × 512 eller 1254 × 1254), en och en eller många i taget som ZIP. Dumpen känner själv igen app, tema och upplösning och sorterar in bilderna. Varje bild får en fast publik länk, och hela teman kan laddas ner som ZIP.

Alla bilder är publika via sin länk, `/bilder/...`. Allt annat, alltså galleriet, uppladdning och radering, kräver inloggning.

## Kom igång

1. **Installera Docker.** På Windows och Mac: [Docker Desktop](https://www.docker.com/products/docker-desktop/). På Linux: paketet `docker.io` (Debian/Ubuntu) eller motsvarande. Podman fungerar också.
2. **Skapa en mapp** och en fil i den som heter `docker-compose.yml`. Klistra in innehållet nedan.
3. **Fyll i** `PUBLIC_URL` (adressen du öppnar Dumpen på) och ett eget `ADMIN_PASSWORD` på minst 8 tecken.
4. **Starta** i den mappen: `docker compose up -d`
5. **Öppna** adressen och logga in med lösenordet.

```yaml
services:
  dumpen:
    image: docker.io/driftaegis/dumpen:1
    restart: unless-stopped
    ports:
      - "8787:8787"
    environment:
      PUBLIC_URL: "http://localhost:8787"
      AUTH_MODE: "password"
      ADMIN_PASSWORD: "change-me-to-a-long-password"
      CF_ACCESS_TEAM_DOMAIN: ""
      CF_ACCESS_AUD: ""
      CLOUDFLARE_API_TOKEN: ""
      CLOUDFLARE_ACCOUNT_ID: ""
    volumes:
      - dumpen-data:/data

  tunnel:
    image: docker.io/cloudflare/cloudflared:latest
    profiles: ["tunnel"]
    restart: unless-stopped
    command: tunnel --no-autoupdate run
    environment:
      TUNNEL_TOKEN: ""
    depends_on:
      - dumpen

volumes:
  dumpen-data:
```

## Inloggning: två sätt

Välj med `AUTH_MODE`.

**`password`** (standard): en inloggningssida med lösenordet i `ADMIN_PASSWORD`. Sessionen gäller i 30 dagar. Om du byter lösenord loggas alla ut.

**`cloudflare-access`**: Cloudflare Access sköter inloggningen, med e-postkod, Google eller annan identitetsleverantör. Dumpen kontrollerar den signerade Access-token själv, så den som tar sig förbi Access släpps ändå inte in. Det kräver ett Cloudflare-konto med en domän:
1. **Skapa en tunnel.** Gå till Zero Trust → Networks → Tunnels, skapa en tunnel och peka ett publikt värdnamn mot `http://dumpen:8787`. Kopiera tunnelns token till `TUNNEL_TOKEN`.
2. **Skapa en Access-applikation.** Gå till Zero Trust → Access → Applications, lägg till en *self-hosted* applikation för samma värdnamn och skapa en policy för vilka som får logga in.
3. **Fyll i compose-filen.** Kopiera applikationens *Application Audience (AUD) Tag* till `CF_ACCESS_AUD` och teamdomänen (`dittteam.cloudflareaccess.com`) till `CF_ACCESS_TEAM_DOMAIN`. Sätt `AUTH_MODE: "cloudflare-access"` och `PUBLIC_URL` till det publika värdnamnet.
4. **Lägg till ett undantag för bilderna.** Skapa en Access-applikation för `<värdnamn>/bilder/*` med policyn *Bypass → Everyone*.
5. **Starta med tunneln:** `docker compose --profile tunnel up -d`

## Inställningar

| Variabel | Krävs | Standard | Betydelse |
|---|---|---|---|
| `PUBLIC_URL` | Ja | `http://localhost:8787` | Adressen Dumpen nås på. Bildlänkarna byggs från den, så ange den publika adressen om bilderna ska användas utanför ditt nätverk. |
| `AUTH_MODE` | Nej | `password` | `password` eller `cloudflare-access`. |
| `ADMIN_PASSWORD` | Med `password` | – | Minst 8 tecken, gärna betydligt längre. |
| `CF_ACCESS_TEAM_DOMAIN` | Med `cloudflare-access` | – | T.ex. `dittteam.cloudflareaccess.com`. |
| `CF_ACCESS_AUD` | Med `cloudflare-access` | – | Access-applikationens AUD-tagg. |
| `CLOUDFLARE_API_TOKEN` | Nej | – | Bara för funktionen "Använd i App Launcher", som sätter ett temas ikoner på dina Cloudflare Access-appar. Behörighet: *Access: Apps and Policies: Edit*. |
| `CLOUDFLARE_ACCOUNT_ID` | Nej | – | Ditt Cloudflare-konto-id, för samma funktion. |
| `TUNNEL_TOKEN` (tjänsten `tunnel`) | Nej | – | Token för Cloudflare Tunnel. |
| `PORT` | Nej | `8787` | Porten inne i containern. |

### Inställningar från en fil i stället

Vill du inte ha värden som lösenord i compose-filen lägger du dem som `NAMN=värde`-rader i filen `import.env` i datavolymen (den som monteras på `/data`) och startar om containern. Vid starten sparas värdena i `/data/settings.env`, som bara containern kan läsa, och `import.env` raderas. För att ändra ett värde senare lägger du en ny `import.env` med bara den raden. En rad med `NAMN=` och inget värde tar bort inställningen. Värden som är ifyllda i compose-filen gäller före sparade värden.

## Data, säkerhetskopiering och uppdatering

- Bilderna ligger i volymen som är monterad på `/data`, som lokal R2-lagring under `/data/v3/r2/`. Metadata om app, tema och storlek följer med varje bild.
- **Säkerhetskopiera:** `docker compose stop`, kopiera volymen och kör `docker compose start`. Du kan också ladda ner varje tema som ZIP i gränssnittet. Den ZIP-filen kan importeras igen precis som den är.
- **Uppdatera:** `docker compose pull && docker compose up -d`.
- **Versioner:** taggarna följer semver. `1` ger alla uppdateringar inom version 1, `1.2` bara rättningar och `1.2.0` exakt en version.

## HTTPS

Containern talar vanlig HTTP på port 8787. Med `cloudflare-access` sköter tunneln HTTPS. Med `password` och åtkomst utifrån behövs en omvänd proxy med certifikat, till exempel Caddy, Traefik eller nginx. Sessionscookien får flaggan `Secure` automatiskt när sidan nås via HTTPS.

## Teknisk översikt

- **Runtime:** Dumpen är skrivet som en Cloudflare Worker. I containern körs den i `workerd`, samma runtime som Cloudflare använder, via `wrangler dev --local` (Miniflare). De två R2-bucketarna (`gallery` och `legacy`) blir lokal lagring under `/data`. Bucketen `legacy` är tom och finns bara för att importfunktionen ska fungera.
- **Lösenordsläget:** sessionen är en cookie (`HttpOnly`, `SameSite=Strict`) med utgångstid och en HMAC-SHA256-signatur, där `ADMIN_PASSWORD` är nyckeln. Lösenord och signatur jämförs i konstant tid, och fel lösenord ger en fördröjning. Ingen sessionsdata sparas på servern.
- **Access-läget:** RS256-signaturen kontrolleras mot teamets publika nycklar, liksom utfärdare, AUD och giltighetstid.
- **Ändringar:** alla ändrande anrop kräver same-origin. Svaren har strikt CSP och övriga säkerhetshuvuden. Bilder serveras bara med `GET` och `HEAD`, och bara för tillåtna sökvägar och filtyper.
- **Imagen** bygger på `node:22-bookworm-slim`, kör som användaren `node` och har en healthcheck. Den byggs i två steg, så att bara den neutraliserade källkoden hamnar i det färdiga lagret.
- **Begränsningar:** `wrangler dev` är en utvecklingsserver som kör en process på en maskin. Det räcker för ett privat bildarkiv men ger inte Cloudflares skalning eller CDN. Bilderna cachas bara med vanliga `Cache-Control`-huvuden.
- **Felsökning:** `docker compose logs -f`.

## Changelog

**1.3.0**
- Inställningar kan ges en gång i `/data/import.env` i stället för i compose-filen. De sparas i `/data/settings.env` och importfilen raderas.
- Imagen byggs från projektets eget repo: `docker build -t dumpen .`.

**1.2.0**
- Första Docker-imagen, med R2 under `/data`.
- Inloggning via `AUTH_MODE`: `password` eller `cloudflare-access`, med valfri Cloudflare Tunnel.
- Funktionen "Använd i App Launcher" tar emot en vanlig API-token.
- Att använda ett tema sparar ingen säkerhetskopia längre. Resultatet bekräftas och läses om från Cloudflare.
- Vid ZIP-import får en temamapp som saknar namn, eller har ett allmänt namn, sitt namn från ZIP-filen.
- Filtervy för bilder och temabibliotek med ZIP-nedladdning och radering. Bilder katalogiseras automatiskt vid import.

## Licens

Dumpen har ingen angiven licens. Den medföljande komponenten `pako` har MIT-licens.
