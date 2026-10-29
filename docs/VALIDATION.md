# Esimese etapi kontroll — 29.10.2026

Godot **4.6.3.stable**, Linuxi pilvekeskkond. Kontrolliti sama projekti päris eksporditud WebAssembly-versiooni Chromiumis.

- **33 läbitud, 0 ebaõnnestunud** mängureeglite ja stseeni kontrolli. Nende seas kogu viie paki missioon koos päriselt tekkivate takistustega, kokkupõrked, ajutine kaitse, punktid, puutejuhtimine, paus, jätkamine ja kohalike rekordite taastamine.
- Brauseris kontrolliti tegelikku sõrmega lohistamist, puutenuppe, pausi ajal seisvat mängupilti ja jätkamist, klaviatuuri ning telefoni- ja lauaarvutiekraanide 9:16 paigutust.
- Veebilõuendi tegelik renderduspuhver kontrolliti vähemalt **1080 × 1920** suurusena; telefonivaate ekraanipildid on täpselt **1080 × 1920**.
- Brauseritest ei tuvastanud JavaScripti, WebGL-i ega Godoti käitusvigu.
- Veebiehitus käivitati korduvalt olemasolevate kontrollitud mallidega. Godoti ametliku arhiivi SHA512 ja eraldatud veebimallide SHA256 kontrollsummad klapivad. ZIP-arhiivi terviklikkus kontrolliti.

Käskude kordamine on kirjeldatud projekti `README.md` failis. Brauseri ekraanipildid ja jagatav veebiarhiiv asuvad kohalikus `artifacts/` kaustas.

Androidi APK-d/AAB-d ega Play poe väljalaset selles etapis ei koostatud. Päris Android-seadme puutejuhtimine, jõudlus, aku kasutus ja turvaalade paigutus on järgmise etapi kontrollid. See on mängitav prototüüp, mitte poe valmisväljalase.

## Veebis avaldamise ettevalmistus

Lisatud on GitHub Pagesi ehitus- ja avaldamistöövoog ning sisu järgi versioonitud mängufailid. Kolm lisatesti kontrollivad, et mängukoodi, graafika ja veebikesta muudatused muudavad versiooni ning genereeritud failid seda ei muuda. CI-s kasutatava ametliku Godoti Linuxi arhiivi SHA512 kontrolliti eraldi.

Kohalik staatilise veebiväljalaske kontroll ja brauseritest ei tõesta iseenesest GitHub Pagesis avaldamist. Avaliku veebisaidi olek tuleb kinnitada pärast GitHubi seadistust ja tegeliku avaldamistöövoo lõppu.

## Kolme piirkonna uuendus — 29.10.2026

- Varasemad 33 mängureeglite ja stseeni kontrolli läbisid.
- 31 tasemete ja profiili kontrolli läbisid: kolme piirkonna terviklikud missioonid päriselt genereeritud takistustega, raskusastmed, külgsuunaline liikumine, kilbi taastamine, lukud, tähed, vanade salvestuste üleminek ning vigaste salvestuste käsitlemine.
- 24 stseeni kontrolli läbisid: tasemevalik, võit, järgmise taseme avamine ja alustamine nii nupu kui Enteriga, kaotuse järel sama taseme kordamine ning edenemise taastamine failist.
- Kolm veebiversiooni kontrolljälje testi läbisid. Kokku 91 automaatkontrolli, lisaks eksporditud mängu brauserikontroll.

Visuaalse uuenduse hulka kuuluvad piirkonna värvid, taseme algusteade, tarneringi edenemisriba, maandumislaine, punktihüpikud, kilbi taastamise teade, laeva valgusjälg ja tulemuse tähed. Efektid peatuvad koos mängupausiga.

Eraldatud brauseriprofiilis kinnitati ka IndexedDB-sse salvestatud edenemise taastamine ja säilimine teise veebiväljalaske laadimisel: valitud kolmas piirkond, avatud tasemed, eraldi tähehinded ja helieelistus jäid alles. Testis kasutati salvestuse andmeid ettevalmistavat prooviprofiili; avaliku mängu profiile ei muudetud.
