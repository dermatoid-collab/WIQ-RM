# Modifiche concordate per la prossima build (non ancora implementate)

Riferimento: foto build 13 su Edge 830, FTP 295 W.

1. **Sweet Spot**: limiti = FTP × 84% e FTP × 97% **troncati** all'intero
   (295 W → 247–286 W), estremi **inclusi** nel conteggio.
2. **Tempi nelle zone**: font meno alto, non deve invadere la riga dell'intervallo;
   cambiare font se serve.
3. **Label Zx in grassetto**: l'Edge 830 non ha font di testo bold → usare un font
   diverso (font bold personalizzato incluso nell'app, solo i caratteri necessari).
4. **Valori delle 3 caselle**: un unico font fisso per tutte, intermedio tra quello
   attuale della casella centrale (numerico bold) e quello delle laterali (testo);
   solo la casella il cui valore non entra (es. >100 min) usa un font più piccolo,
   di poco.
5. **Label delle 3 caselle**: font leggermente più grande.
6. Punti 4 e 5 valgono anche per **NP / Media / Pot. 3s**.
7. **Zona attuale**: riquadro sulla zona come ora; le due frecce laterali si
   spostano in verticale in modo continuo in base ai W (in basso = limite inferiore
   della zona, in alto = limite superiore). Z1 parte da 0 W; Z7 ha come limite
   superiore il 200% FTP (590 W); oltre, la freccia resta al limite superiore.
8. **Spazio tra label Zx e tempo**: aumentarlo, tempo leggermente più a destra.
9. **Formato nelle caselle** (solo lì): minuti totali `mm:ss`, es. 1:22:30 → `82:30`.
   Nelle righe delle zone resta `m:ss` sotto l'ora, `h:mm:ss` sopra.
10. **Percentuali a destra**: font leggermente più grande.
