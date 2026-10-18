# AGENTS.md

- Gemensamma regler för arbetssätt, deploy, loggning, kostnader och Docker finns i [CLAUDE.md](CLAUDE.md). Arbetet sker lokalt; GitHub är sparpunkten och färdiga delar går in i `main` via en pull request.
- Läs [README.md](README.md) före större ändringar.
- `src/index.js` är skriven för Workers Static Assets. Det som deployas är `dist/worker.js`, som `build.mjs` bygger med `public/` inbäddat och produktionens variabler injicerade. Ändra källan, inte `dist/`.
- Bara `/bilder/*` är publikt. Allt annat kräver inloggning: Cloudflare Access-JWT i produktion, eller `AUTH_MODE=password` i en egen installation. Sätt aldrig `AUTH_MODE` eller `LOCAL_DEV` i produktion.
- Skanna R2 inkrementellt: dimensioner kommer från `customMetadata` eller edge-cachen, och en range-läsning sker bara en gång per objektversion. Ingen fullständig omskanning per förfrågan.
- Kör `npm test` före deploy.
- Koden innehåller inga personliga värden, bara platshållare (`__NAMN__`) som deklareras i `cloudflare.example.env` och fylls i av `tools/render.mjs` vid deploy och av `docker/entrypoint.sh` i containern. Se regeln i `CLAUDE.md`. Uppdatera `CHANGELOG.md` och versionen i `package.json` vid varje ny image.
- Lägg aldrig API-tokens eller andra secrets i repository eller publik dokumentation.
