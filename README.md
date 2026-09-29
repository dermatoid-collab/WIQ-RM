# Power Zones SS — data field Connect IQ per Garmin Edge

Data field a tutto schermo che mostra il **tempo nelle zone di potenza Coggan (%FTP)**
più tre totali dedicati: **Sweet Spot**, **Z4** e **Z4+** (Z4 + Z5 + Z6 + Z7).
Ispirato a [Power Zones](https://apps.garmin.com/apps/ff098e11-5024-42c0-8a2b-92fda75a23aa).

Target: Edge 830 e Edge 840 (testato solo a livello di codice); inclusi anche 530, 540, 1040, 1050.

## Layout

```
┌──────────────────────────────┐
│▌Z7 > 375W                    │
│▌Z6 301 - 375W                │
│▌Z5 263 - 300W                │
│▌Z4 226 - 262W   0:04:10  6%  │
│▶Z3 188 - 225W   0:21:37 31% ◀│  ← zona attuale (bordo + frecce)
│▌Z2 138 - 187W   0:35:02 50%  │  ← barra colorata = % del tempo
│▌Z1 0 - 137W     0:09:11 13%  │
├─────────┬─────────┬──────────┤
│   SS    │   Z4    │   Z4+    │  ← evidenziato se ci sei dentro ora
│ 0:12:40 │ 0:04:10 │ 0:04:10  │
├─────────┼─────────┼──────────┤
│   Max   │  Media  │ Potenza  │  ← ultima cella nel colore della zona
│   512   │   196   │   234    │
└─────────┴─────────┴──────────┘
```

- **Pagina intera** (altezza ≥ 240 px): 7 zone + striscia SS/Z4/Z4+ + Max/Media/Potenza.
  Se lo spazio lo permette, ogni zona va su due righe come nell'originale, altrimenti su una.
- **Metà pagina**: solo SS/Z4/Z4+ e Max/Media/Potenza.
- **Campo piccolo**: solo SS/Z4/Z4+.
- Supporta sfondo chiaro e scuro (in modalità notte la barra di percentuale diventa una linea sottile).

## Come conta il tempo

- Si usa la **potenza a 1 s** (come fanno TrainingPeaks/Intervals.icu), solo con **timer attivo**:
  pausa e auto-pausa non contano.
- 0 W (ruota libera) conta in Z1; se il misuratore di potenza non trasmette, non conta nulla.
- La zona evidenziata e la potenza visualizzata usano la media impostata (default 3 s) per non sfarfallare.
- Reset del giro/attività (salva/elimina) azzera i totali.
- I tre totali SS / Z4 / Z4+ vengono **scritti nel file FIT** (campi di sessione, in minuti)
  e compaiono nel riepilogo attività di Garmin Connect.

## Zone predefinite (Coggan)

| Zona | %FTP | FTP 250 W |
|------|------|-----------|
| Z1 Recupero attivo | ≤ 55 | 0 – 137 |
| Z2 Endurance | 56 – 75 | 138 – 187 |
| Z3 Tempo | 76 – 90 | 188 – 225 |
| Z4 Soglia | 91 – 105 | 226 – 262 |
| Z5 VO2max | 106 – 120 | 263 – 300 |
| Z6 Capacità anaerobica | 121 – 150 | 301 – 375 |
| Z7 Neuromuscolare | > 150 | > 375 |
| **Sweet Spot** | 88 – 94 | 220 – 235 |

Limite superiore di ogni zona = `floor(FTP × % / 100)`. Sweet Spot si sovrappone a Z3/Z4 e viene
contato in parallelo.

## Impostazioni

FTP, limiti Sweet Spot, limiti Z1–Z6, media della potenza visualizzata (1/3/5/10 s), intervalli
in W o %FTP, ultima cella (Potenza o %FTP). Il data field non può leggere l'FTP dal profilo Garmin
(l'API Connect IQ non lo espone), quindi va impostato qui.

- **Installato da Connect IQ Store** (se lo pubblichi): impostazioni dall'app Connect IQ sul telefono.
- **Installato in sideload**: modifica i valori di default in
  [`resources/settings/properties.xml`](resources/settings/properties.xml) (es. `ftp`) e ricompila.
  In alternativa, nel simulatore usa *File → Edit Application Settings*, poi copia il file `.SET`
  generato in `GARMIN/APPS/SETTINGS/` sull'Edge con lo stesso nome del `.prg`.

## Compilare e installare

1. Installa il [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (SDK Manager) e scarica
   i device Edge 830 / 840. Consigliata l'estensione Monkey C per VS Code.
2. Genera una developer key (una volta sola):
   ```sh
   openssl genrsa -out developer_key.pem 4096
   openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
   ```
3. Compila:
   ```sh
   monkeyc -f monkey.jungle -d edge840 -o bin/PowerZonesSS.prg -y developer_key.der
   monkeyc -f monkey.jungle -d edge830 -o bin/PowerZonesSS_830.prg -y developer_key.der
   ```
4. Prova nel simulatore: `connectiq` e poi `monkeydo bin/PowerZonesSS.prg edge840`
   (*Simulation → Data Fields* / file FIT per simulare la potenza).
5. Sideload: collega l'Edge via USB e copia il `.prg` in `GARMIN/APPS/`. Poi sul ciclocomputer:
   profilo attività → Schermate dati → layout a 1 campo → Connect IQ → *Power Zones SS*.

## Struttura

```
manifest.xml                  device, permessi (FitContributor), lingue ita/eng
monkey.jungle
source/PowerZonesApp.mc       AppBase
source/PowerZonesView.mc      logica zone + disegno
resources/                    stringhe (eng), impostazioni, campi FIT, icona
resources-ita/                stringhe italiane
```
