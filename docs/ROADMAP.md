# Kosmosekuller: järgmine mängitav etapp

## Selle uuenduse teostus

1. **Lahing.** Ühe sõrmega juhtimine jääb alles; automaattuld saab välja lülitada. Kolm asteroidiklassi: väike (1 tabamus, 0 münti), keskmine (3 tabamust, juhuslikult 1–3 münti), suur (6 tabamust, juhuslikult 4–7 münti). Tabamused, mürsud ja purunemine saavad nähtava tagasiside. Asteroidi rammimine münte ei anna.
2. **100 taset.** Kümme piirkonda, igas kümme järjest avatavat taset. Tarneeesmärk varieerub 2–7 pakini. Iga kümne taseme järel kasvavad kiirus, tihedus ja triiv; maksimaalne kiirus on piiratud. Viimane tase lõpetab kampaania. Varasemate kolme taseme tähed ja avatus säilivad.
3. **Majandus.** Lennuraja mündilaine annab senise kolme asemel ühe mündi (sama sagedus). Pakk annab kaks münti. Kõik tegelikult teenitud mündid lisanduvad kohe püsivasse rahakotti, ka kaotuse või menüüsse naasmise korral. Punkte ja kulutatavaid münte näidatakse eraldi. Vanas versioonis rahakotti ei salvestatud, seega varasemast rekordist münte ei oletata.
4. **Menüüd ja pood.** Avaleht, kümne tasemega lehtedeks jaotatud tasemekaart ning pood. Müntidega kaks laevavälimust ja kaks lennujälge. Omamine ja kasutatav välimus salvestuvad. Kosmeetika ei muuda relva, kiirust ega kilpe.
5. **Halloween 2026.** 15.10.–07.11.2026 saab poest tasuta Kõrvitsakulleri; see jääb omanikule alles. Öötiib on tasulise hooajalaeva eelvaade. Veebiprototüübis raha ei küsita ega tasulist eset müntidega avata. Hooaeg kasutab seadme UTC kuupäeva; avaldamiseks vajab piiratud pakkumine usaldatud serveriaega.
6. **Kontroll ja avaldamine.** Reeglid, kõik 100 missiooni, salvestuse üleminek, rahakott, ostud/varustamine, menüüd ja tegelik veebiversioon. Avaldada alles pärast kontrollide läbimist samale GitHub Pagesi aadressile.

Punktid 1–5 on selles prototüübis teostatud. Kohalikud kontrollid läbisid: 334 automaatkontrolli ja mõlemad päris WebAssembly-mängu brauseritestid. Avaldamist kontrollib lisaks GitHubi töövoog.

## Tasuliste asjade suund

Tasuliseks sobivad hooaja erikujundusega laevad ja kosmeetikakomplektid. Tasuta/müntidega sisu peab jätkuvalt lubama kogu kampaania läbida. Esimene tasuta hooajakingitus annab hea põhjuse mängu tagasi tulla. Esialgsed mündihinnad on proovitasakaal, mida tuleb päris mängijatega mõõta.

## Järgmised eraldi etapid

- Androidi APK ning päris telefoni jõudluse ja juhtimise kontroll.
- Google Play Billing, ostu tõendamine, ostude taastamine ning usaldatud hooajateenus enne pärisostude avamist. Premium-hinda ei mõelda brauseris välja; see tuleb poest koos kohaliku valuutaga.
- Mängijate tagasiside põhjal raskuse ja mündihindade täpsustamine, seejärel uued takistused ja hooajaülesanded.
