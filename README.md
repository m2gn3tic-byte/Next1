# Kosmosekuller 🚀

Ühe sõrmega juhitav 2D-kosmoseseiklus Androidi jaoks. **Mängitav Godot 4.6.3 prototüüp kolme avatava piirkonnaga**, millel on ka brauseris käivitatav versioon.

Lenda läbi asteroidide, kogu münte ja vii viis pakki planeetidele. Maandumiseks hoia laeva pool sekundit helendavas ringis. Kolm kilpi annavad eksimisruumi; iga kohaletoimetamine annab uue turvalise stardi.

Mängi veebis: **https://m2gn3tic-byte.github.io/Next1/**.

## Tasemed ja edenemine

| Tase | Piirkond | Lennu iseloom |
| --- | --- | --- |
| 1 | Mündiorbiit | Rahulik algus, otse liikuvad asteroidid |
| 2 | Udumets | Lillakas piirkond, kiirem lend ja külgsuunas triivivad asteroidid |
| 3 | Kristallivöö | Kuldne piirkond, tihedam liiklus ja tugevam triiv |

Iga piirkonna viis tarnet avavad järgmise taseme. Tulemusele antakse 1–3 tähte allesjäänud kilpide järgi; varasemat taset saab parema tulemuse nimel uuesti mängida. Teine ja neljas tarne taastavad ühe kaotatud kilbi. Viimase taseme lõpetamisel saab sama rada korrata.

Avatud tasemed, valik ja parimad tähed salvestatakse brauserisse koos olemasoleva rekordi ja helieelistusega. Varem esimese viie pakiga lennu lõpetanud mängijale avaneb uuendamisel teine piirkond. Mängijale näidatakse ka piirkonna algust, tarne edenemist, punktihüpikuid, maandumislaineid ja laeva valgusjälge.

## Käivitamine

**Godotis:** impordi [project.godot](project.godot) Godot 4.6.3-s ja vajuta **F6** avatud `scenes/main.tscn` stseenis või **F5** kogu projekti käivitamiseks. Lisateeke ega väliseid teenuseid pole vaja.

**Selles pilvekeskkonnas:**

```bash
cd /workspace/Next1
./tools/build_web.sh
python3 tools/serve_web.py
```

Kohalik server kasutab porti `8060`. Veebiversioon on kaustas `build/web`; jagatav arhiiv on `artifacts/kosmosekuller-web.zip`. Arhiivi sees olev `PLAY.txt` selgitab selle avamist. HTML-i otse failina avamise asemel on vaja kohalikku HTTP-serverit.

Esimene veebiehitus kontrollib Godoti versiooni ja paigaldab puuduvad ametlikud ekspordimallid (allalaadimine ligikaudu 1,26 GB). Arhiivi kontrollitakse kinnitatud SHA512 ja eraldatud malle SHA256 kontrollsummadega. Järgmised ehitused kasutavad kohalikke malle. Olemasolevat arhiivi saab kasutada käsuga `python3 tools/install_web_templates.py --archive /tee/templates.tpz`.

**Püsiv veebiaadress:** [GitHub Pagesi juhend](docs/WEB.md) kirjeldab ühekordset sisselülitamist. Töövoog `.github/workflows/web.yml` ehitab ja kontrollib iga `main` harusse avaldatud uuenduse ning avaldab eduka versiooni samale aadressile. Versioonitud mängufailid väldivad vana mängu püsimist brauseri vahemälus. See eeldab GitHub Pagesi aktiveerimist; kohalik ehitus üksi ei tähenda, et mäng on veebis avaldatud.

## Juhtimine ja punktid

| Tegevus | Telefon | Arvuti |
| --- | --- | --- |
| Juhtimine | Libista sõrmega mänguväljal | Lohista hiirega või kasuta nooleklahve / WASD |
| Alusta / jätka | Puuduta nuppu | Puuduta nuppu või vajuta Enter |
| Paus | Nupp üleval paremal | P / Esc või pausivajutus |
| Heli | Noodinupp | Noodinupp |

- Ekraani puudutamine ei teleporteeri laeva: liikumine järgib sõrme suhtelist nihet.
- Münt annab **20 punkti**, pakk **150 punkti ja 5 münti**.
- Viie paki kohaletoimetamine lõpetab missiooni ning annab **300 + 100 × allesjäänud kilpide arv** lisapunkti.
- Mäng peatub fookuse kaotamisel. Rekord ja helieelistus salvestatakse seadmesse (`user://courier.cfg`; veebis brauseri kohalikku salvestusse).
- Mänguvälja alusresolutsioon on **1080 × 1920 (9:16)**. Teiste ekraanisuhete korral säilivad proportsioonid.

## Kontrollimine

Põhireeglite, tervikliku missiooni, salvestamise ja tegeliku stseeni juhtnuppude testid:

```bash
./tools/godot.sh --headless --editor --import --quit
./tools/godot.sh --headless --script res://tests/run_tests.gd
./tools/godot.sh --headless --script res://tests/level_tests.gd
./tools/godot.sh --headless --script res://tests/progression_scene_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py'
```

Brauseritest vajab Python Playwrighti, Pillow't ja Chromiumi ning käivitatud kohalikku serverit:

```bash
python3 tests/browser_smoke.py
```

Brauseritest käivitab päriselt eksporditud WebAssembly-mängu, kontrollib sõrmega lohistamist, pausi ja jätkamist, klaviatuuri ning eri ekraanisuhete paigutust. Ekraanipildid salvestatakse kausta `artifacts/`. Pilvekeskkonna võrgupiirangute korral tuleb server ja brauser käivitada tööriista lubatud võrgurežiimis.

## Projekti ülesehitus

| Fail või kaust | Sisu |
| --- | --- |
| `scripts/run_state.gd` | Joonistamisest sõltumatud mängureeglid ja külvatava juhuarvugeneraatoriga maailm |
| `scripts/main.gd` | Puute- ja klaviatuurijuhtimine, kasutajaliides, joonistamine ja sünteesitud helid |
| `scripts/profile.gd` | Kohalikud rekordid ja sätted |
| `scripts/levels.gd` | Kolme piirkonna värvid ja raskusastmed |
| `assets/` | Selle mängu jaoks loodud SVG-graafika ja DejaVu fondid koos litsentsiga |
| `tests/` | Mängureeglite, stseeni ja brauseri kontrollid |
| `tools/` | Godoti käivitus, kontrollsummadega mallipaigaldus, veebiehitus ja kohalik server |

## Esimese etapi piirid ja järgmine samm

Valmis on kolme piirkonnaga mänguring: tasemevalik → lend → viis kohaletoimetamist või kilpide kaotus → tulemus → järgmine tase või uus katse. Graafika on kontseptpildist inspireeritud esialgne 2D-vektorkujundus.

Järgmine etapp on **Androidi prooviversioon ja testimine päris telefonil**: Android SDK / JDK 17 seadistus, Androidi ekspordipreset, APK ning juhtimise ja jõudluse kontroll. Praegune veebitest emuleerib telefoni; päris Android-seadmel pole seda versiooni veel kontrollitud. Play poe AAB, avaldamisallkiri, ostud ja reklaamid lisanduvad hiljem. Reklaami- ega makse-SDK-sid selles prototüübis ei ole.

Godoti wrapper hoiab pilvekeskkonna kirjutatavad vahemälud kaustas `.local/`, ekspordimallid kaustas `.tools/` ning ehitused kaustas `build/`. Need ei kuulu lähtekoodi hulka. Kasuta selle isoleeritud pilveülesande olemasolevat töökoopiat; uut Git worktree'd pole vaja.
