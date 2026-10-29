# Kosmosekuller 🚀

Ühe sõrmega juhitav 2D-kosmoseseiklus Androidi jaoks. **Godot 4.6.3 mängitav prototüüp: 100 taset, automaattuli, kolm asteroidiklassi, püsiv rahakott, kosmeetikapood, 24 keelt ja tasuta Halloweeni hooajarada.**

Mängi veebis: **https://m2gn3tic-byte.github.io/Next1/**.

Lenda läbi asteroidide ja vii pakid planeetidele. Laev tulistab automaatselt; saad tule nupust või tühikuklahviga peatada. Maandumiseks hoia laeva pool sekundit helendavas ringis. Kolm kilpi annavad eksimisruumi.

## Tasemed ja edenemine

Kampaanias on kümme piirkonda, igas kümme järjest avatavat taset: Mündiorbiit, Udumets, Kristallivöö, Komeedisadam, Roosakas udu, Jääpeegel, Päikesetuul, Smaragdkaar, Öölaternad ja Tähevärav. Tasemekaart näitab korraga kümmet sihtkohta ning lubab ka lukustatud piirkondi ette vaadata.

Tarneeesmärk varieerub **2–7 pakini**. Iga kümne taseme järel kasvavad kiirus, asteroidide tihedus ja triiv. Kiiruse ülempiir on 480 loogilist pikslit sekundis ning tekkeintervall vähemalt 0,72 sekundit. Viimane, 100. tase lõpetab kampaania. Varasemaid tasemeid saab parema tähehinde nimel korrata.

Võit avab järgmise taseme ning annab allesjäänud kilpide järgi 1–3 tähte. Iga teine tarne taastab ühe puuduva kilbi, kui missioon veel jätkub. Edenemine, parimad tähed, rekord ja sätted salvestuvad samasse brauserisse. Vana kolme piirkonna salvestus säilib; varem kolmanda lõpetanule avaneb neljas tase.

## Lahing ja mündid

| Asteroid | Tabamusi | Müntide auhind | Punktid |
| --- | --- | --- | --- |
| Väike | 1 | 0 | 10 |
| Keskmine | 3 | Juhuslikult 1–3 | 30 |
| Suur | 6 | Juhuslikult 3–5 | 60 |

Auhind tuleb ainult tulistades purustamise eest. Rammimine võtab ühe kilbi. Ühe asteroidi mündiauhinna ülempiir on **5**. Mürsud, tabamused, allesjäänud vastupidavus ja purunemine on nähtavad. Purunemisel lendavad ebakorrapärased pöörlevad kivikillud kogu 360° ulatuses laiali, kahanevad ja hajuvad 0,65–1,25 sekundiga. Need on visuaalsed ega anna lisamünte. Mängupaus peatab ka mürsud ja kõik killud; korraga on lubatud kuni 240 kildu.

Lennurajal tekib mündilainega senise kolme asemel **üks münt**, sama 2,1-sekundilise intervalliga. Korjatud münt annab 20 punkti; pakk annab 150 punkti ja **2 münti**. Võiduboonus on 300 + 100 × allesjäänud kilpide arv punkti. Punkte poes kulutada ei saa.

Teenitud mündid lisatakse kohe püsivasse rahakotti; need jäävad alles ka kaotuse ja katkestatud lennu korral. Vana versioon ei salvestanud mündisaldot, seega varasemast punktirekordist raha ei tuletata. Kõik andmed on lokaalsed: brauseri andmete kustutamine kustutab ka rahakoti, edenemise ja kosmeetika.

## Pood ja Halloween

| Ese | Hind / ligipääs |
| --- | --- |
| Virmalise laevavälimus | 90 münti |
| Komeedi laevavälimus | 180 münti |
| Udujälg | 60 münti |
| Kuldjälg | 100 münti |
| Kõrvitsakuller | Tasuta Halloweeni kingitus 15.10.–07.11.2026 |
| Öötiib | Tasulise hooajalaeva **eelvaade**; pärisostud pole aktiveeritud |

Eseme omamine ja kasutatav laev/jälg salvestuvad; algse laeva ja jälje saab tasuta tagasi valida. Kõrvitsakuller jääb ka pärast hooaega kasutatavaks. Kõik laevad kasutavad sama relva, kiirust ja kilpe. Pood muudab välimust.

Hooaeg kasutab prototüübis seadme UTC kuupäeva. Enne päris rahaga müümist on vaja Google Play Billingut, ostude tõendamist/taastamist ja hooaja usaldatud aega. Veebiversioon ei küsi makseandmeid ega anna premium-eset kohalike müntide eest. Arenduse [plaan ja järgmised etapid](docs/ROADMAP.md).

## Keeled

Menüü **文A** avab 24 salvestuva keelevaliku: eesti, inglise, hispaania, portugali (Brasiilia), prantsuse, saksa, itaalia, hollandi, poola, rumeenia, soome, rootsi, türgi, vene, ukraina, kreeka, indoneesia, vietnami, tai, araabia, hindi, lihtsustatud hiina, jaapani ja korea.

Täiesti uue mängija keel valitakse seadme järgi; toetamata keele puhul kasutatakse inglise keelt. Senised eesti keeles salvestused säilitavad eesti keele. Valikut saab alati peamenüüs muuta. Tõlgitud on menüüd, tasemepiirkonnad, juhised, pood, tulemused, hüpikteated ja hooajarada. Araabia tekst kasutab õiget kirjasuunda ning eraldab arvusuhted ja XP vasakult paremale loetavateks osadeks.

Kõik tõlked ja fondid on kaasa pakitud, mäng ei vaja tõlketeenust. Noto fondid lisavad araabia kõrval ka hindi, tai ja Ida-Aasia kirjamärkide toe. CJK-fondist kaasatakse ainult kasutatavad märgid, ligikaudu 230 kB. Täpne muutmis- ja fondijuhend: [LOCALIZATION.md](docs/LOCALIZATION.md). Tõlked on prototüübi esialgne tekst; enne poeväljalaset on vaja emakeelsete mängijate keelelist tagasisidet.

## Tasuta Halloweeni battle pass

Hooaeg on **15.10.–07.11.2026**, kümme astet, iga aste vajab 200 XP (kokku 2000). Asteroidi purustamine annab 5 XP, mündi korjamine 2 XP, tarne 25 XP ja võit 50 XP. XP ja teenitud mündid salvestatakse ühe tehinguna. XP kasv peatub hooaja lõppedes; juba teenitud auhindu saab hiljemgi võtta.

Esimesed üheksa astet annavad vastavalt 10, 15, 20, 25, 30, 35, 40, 45 ja 50 münti. Kümnes avab **Kuukiire lennujälje**, mis jääb alles ja mida saab hooajarajalt uuesti kasutusele võtta. Sama auhinda saab võtta ainult ühe korra. Need on eraldi hooajaauhinnad; ühe asteroidi auhind jääb alati kuni viiele mündile.

Kõik kümme auhinda on tasuta teenitavad. Premium-osa on informatiivne eelvaade; ostu ega XP-ostmise võimalust pole. Hooaeg kasutab prototüübis seadme UTC aega ja kohalikku salvestust; pärisostud vajavad hiljem usaldatud ostu- ja hooajateenust.

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
| Automaattuli | Nupp all paremal | Sama nupp või tühikuklahv |

- Ekraani puudutamine ei teleporteeri laeva: liikumine järgib sõrme suhtelist nihet.
- Mäng peatub fookuse kaotamisel. Rekord ja helieelistus salvestatakse seadmesse (`user://courier.cfg`; veebis brauseri kohalikku salvestusse).
- Mänguvälja alusresolutsioon on **1080 × 1920 (9:16)**. Teiste ekraanisuhete korral säilivad proportsioonid.

## Kontrollimine

Põhireeglite, tervikliku missiooni, salvestamise ja tegeliku stseeni juhtnuppude testid:

```bash
./tools/godot.sh --headless --editor --import --quit
./tools/godot.sh --headless --script res://tests/run_tests.gd
./tools/godot.sh --headless --script res://tests/level_tests.gd
./tools/godot.sh --headless --script res://tests/progression_scene_tests.gd
./tools/godot.sh --headless --script res://tests/combat_economy_tests.gd
./tools/godot.sh --headless --script res://tests/localization_pass_debris_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py'
```

Brauseritest vajab Python Playwrighti, Pillow't ja Chromiumi ning käivitatud kohalikku serverit:

```bash
python3 tests/browser_smoke.py
python3 tests/browser_economy.py
python3 tests/browser_season_language.py
```

Brauseritest käivitab päriselt eksporditud WebAssembly-mängu, kontrollib sõrmega lohistamist, pausi ja jätkamist, klaviatuuri ning eri ekraanisuhete paigutust. Poe brauserikontroll proovib lisaks oste, tasuta kingitust, salvestuse üleminekut ja nähtavat tulistamist eraldatud prooviprofiilis. Ekraanipildid salvestatakse kausta `artifacts/`. Pilvekeskkonna võrgupiirangute korral tuleb server ja brauser käivitada tööriista lubatud võrgurežiimis.

## Projekti ülesehitus

| Fail või kaust | Sisu |
| --- | --- |
| `scripts/run_state.gd` | Joonistamisest sõltumatud mängureeglid ja külvatava juhuarvugeneraatoriga maailm |
| `scripts/main.gd` | Puute- ja klaviatuurijuhtimine, kasutajaliides, joonistamine ja sünteesitud helid |
| `scripts/profile.gd` | Edenemine, rahakott, kosmeetika ja sätted |
| `scripts/catalogue.gd` | Kosmeetika hinnad, õigused ja Halloweeni aeg |
| `scripts/text.gd`, `assets/i18n/` | 24 keele tekstid, seadmekeele valik ja arvusuund |
| `scripts/season_pass.gd` | Kümne tasuta hooajaauhinna määratlus |
| `scripts/debris.gd` | Piiratud mahuga pöörlevad ja hajuvad asteroidikillud |
| `scripts/levels.gd` | 100 taseme tarneeesmärgid, piirkonnad ja raskus |
| `assets/` | Selle mängu jaoks loodud SVG-graafika ja DejaVu fondid koos litsentsiga |
| `tests/` | Mängureeglite, stseeni ja brauseri kontrollid |
| `tools/` | Godoti käivitus, kontrollsummadega mallipaigaldus, veebiehitus ja kohalik server |

## Piirid ja järgmine samm

Valmis on 100 tasemega mänguring: peamenüü/pood → tasemevalik → lend ja tulistamine → 2–7 tarnet või kilpide kaotus → tulemus → järgmine tase või uus katse. Graafika on kontseptpildist inspireeritud esialgne 2D-vektorkujundus.

Järgmine etapp on **Androidi prooviversioon ja testimine päris telefonil**: Android SDK / JDK 17 seadistus, Androidi ekspordipreset, APK ning juhtimise ja jõudluse kontroll. Praegune veebitest emuleerib telefoni; päris Android-seadmel pole seda versiooni veel kontrollitud. Play poe AAB, avaldamisallkiri, ostud ja reklaamid lisanduvad hiljem. Reklaami- ega makse-SDK-sid selles prototüübis ei ole.

Godoti wrapper hoiab pilvekeskkonna kirjutatavad vahemälud kaustas `.local/`, ekspordimallid kaustas `.tools/` ning ehitused kaustas `build/`. Need ei kuulu lähtekoodi hulka. Kasuta selle isoleeritud pilveülesande olemasolevat töökoopiat; uut Git worktree'd pole vaja.
