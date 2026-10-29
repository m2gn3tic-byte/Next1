# Püsiv veebiversioon

GitHub Pages saab serveerida mängu staatilist veebieksporti. Mäng ei vaja kasutajakontot ega mänguserverit. Kõik Godoti failid kasutavad suhtelisi aadresse, seega töötab eksport ka projekti alamteel.

## Ühekordne GitHubi seadistus

1. Ava repositooriumi **Settings → Pages**: https://github.com/m2gn3tic-byte/Next1/settings/pages.
2. Vali **Build and deployment → Source → GitHub Actions**. GitHubi pakett peab toetama Pagesi selles hoidlas; hoidla nähtavust ei ole vaja ega lubatud automaatselt muuta.
3. Kui kood on `main` harus, käivita **Actions → Build and publish game → Run workflow** või avalda järgmine muudatus `main` harusse.
4. Eduka töövoo `deploy` samm näitab tegelikku veebiaadressi. Kasuta seda aadressi; enne õnnestunud avaldamist pole veebilingi toimimine kinnitatud.

`actions/configure-pages` ei saa tavalise töövoo `GITHUB_TOKEN`-iga Pagesi esmakordselt sisse lülitada. Selleks sobib ülaltoodud ühekordne seadistus või olemasolevate piisavate õigustega GitHubi ligipääs. Uut salavõtit ei ole vaja pelgalt töövoo käivitamiseks lisada.

## Iga järgmine uuendus

Muudatus `main` harus käivitab automaatselt ametliku kontrollsummaga Godoti paigalduse, veebiehituse, mängureeglite ja brauseri testid ning avaldamise. Ebaõnnestunud ehitust ei avaldata. Pull request'id käivitavad ehituse ja testid ilma avaldamiseta.

Veebiaadress jääb samaks. JavaScripti, mängupaki ja WebAssembly failinimed sisaldavad mängu sisu kontrolljälge. Seetõttu laeb uus leht uued mängufailid ka siis, kui brauseril on eelmise versiooni failid vahemälus. Avatud mängus tuleb uue versiooni saamiseks leht uuesti laadida.

Avaldatud versiooni saab kontrollida:

```bash
python3 tools/verify_web.py TEGELIK_VEEBIAADRESS \
  --expected-version "$(python3 tools/web_release.py fingerprint)"
```

See kontrollib päriselt teenindatavat `version.json` faili, HTML-i, versioonitud mängufaile ja WebAssembly MIME-tüüpi. Kohalik ehitus ja ZIP on endiselt saadaval käsuga `./tools/build_web.sh`.

## Pilvekeskkonna ühendus

GitHubi haldus-API ja avaldatud mängu kontroll vajavad lubatud sihtkohti `api.github.com` ning `m2gn3tic-byte.github.io`. Need on lisatud pilvekeskkonna seadistuse mustandisse. Mustandi salvestamine ei muuda jooksva masina võrgureegleid: muudatused tuleb keskkonna seadetes üle vaadata, salvestada ja keskkond avaldada.

Kui API või veebisaidi kontroll on võrgu tõttu keelatud, ei kinnita see puuduvat GitHubi autentimist. Kasuta olemasolevat platvormi autentimist ja kontrolli toimingut uuesti pärast võrguseadistuse rakendumist.
