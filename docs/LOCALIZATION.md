# Keeled ja fondid

`assets/i18n/strings.json` sisaldab 24 täielikku tõlkepakki, igas 117 stabiilset võtit. `scripts/text.gd` hoiab toetatud koodid, nende omakeelsed nimed, esmakäivituse seadmekeele vastenduse ning inglise varutekstid. Esmakäivituse automaatvalik ei kirjuta üle olemasolevat salvestust. Valitud keel salvestub koos rahakoti ja hooajarajaga.

Kasutajaliidese staatilistel juhtnuppudel on tõlkevõtme metaandmed; muutuvad arvud vormindatakse sama paki järgi. Tasemete ja kosmeetika püsivad ID-d ei sõltu keelest. Keelt muutes uuenevad tekstid kohe, menüü ei käivita uut mängu. Pikkade tekstide kirjasuurus kohandub määratud 1080×1920 paigutuse laiusele.

Araabia ühendatud tähed ja tekstisuund tulevad Godoti kujundajast. Arvusuhted, vahemikud ja XP eraldatakse Unicode LRI/PDI markeritega, et näiteks `1 / 100` ei pöörduks ümber. Markerite uuesti lisamine on idempotentne. Käesolev paigutus säilitab mängunuppude asukohad eri keeltes.

## Tekstide muutmine

1. Muuda sama võtit kõigis 24 pakis; säilita vormindusparameetrite järjekord ja tüüp (`%s`, `%02d`). Reavahetus on JSON-is `\n`.
2. Uue võtme kasutamisel seo staatiline silt/nupp tõlkevõtmega või kutsu muutuva teksti puhul `CourierText.t(key, args)`.
3. Uue CJK märgi lisamisel genereeri allpool kirjeldatud fondialamhulk uuesti.
4. Käivita Python-kontrollid ning `tests/localization_pass_debris_tests.gd`. Need kontrollivad pakke, parameetreid, iga keele märgitoetust, menüüde tekstilaiust ja salvestamist. `tests/browser_season_language.py` vajutab päris eksporditud WebAssembly-mängus kõiki 24 valikut ning kontrollib keele ja hooajaandmete taastamist brauseris.

Esialgsete tõlgete loomulikkust tuleb enne Play poe väljalaset kontrollida emakeelsete mängijatega.

## Fondid ja päritolu

Põhifondid on DejaVu Sans ja Bold. Hindi jaoks on kaasas Noto Sans Devanagari ning tai jaoks Noto Sans Thai. Hiina, jaapani ja korea kasutavad ümbernimetatud **Courier CJK UI** alamhulka ametlikust Noto Sans CJK SC Regular 2.004 fondist. Need on DejaVu fallback-fondid ja töötavad võrguta.

`assets/fonts/Noto-SOURCES.json` talletab ametlikud HTTPS-allikad (versioonitud Noto CJK ning täpse Git commit'iga Google Fonts), algfailide SHA256 ja suurused. SIL Open Font License tekstid on samas kaustas ning lisatakse veebiarhiivi `THIRD_PARTY_NOTICES.txt` faili. CJK alamhulga nimi on muudetud; algsed autoriõiguste ja litsentsi teated säilivad.

CJK alamhulga taastamiseks laadi manifestis viidatud algfont, kontrolli SHA256 ning kasuta arendustööriista FontTools:

```bash
python3 tools/subset_cjk.py /tee/NotoSansCJKsc-Regular.otf
```

Tööriist kontrollib algfondi SHA256, kogub CJK märgid tõlgetest ja mängukoodist, säilitab kujundustabelid ning kirjutab ümbernimetatud OTF-faili. Praegune 652 märgiga alamhulk on ligikaudu 230 kB, mitte kogu 16 MB algfont. Täielikud hindi ja tai fondid tagavad liittähtede ja diakriitikute kujunduse. Mängu ehitamine ise FontToolsi ega fontide allalaadimist ei vaja.
