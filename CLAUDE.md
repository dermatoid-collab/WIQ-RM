# Power Zones SS — note per Claude

- Lingua con l'utente: italiano.
- Target principale: Edge 830 (anche 840). FTP utente 295 W.
- Ogni push avvia una build (GitHub Actions); per commit solo di documentazione usare `[skip ci]`.
- **Screenshot del simulatore: solo se concordati con l'utente.** Non proporli né
  avviarli di propria iniziativa. Quando concordati: commit con `[screenshots]` nel
  messaggio (o run manuale con l'opzione), poi `git fetch origin screenshots`.
- Prima di modificare, riepilogare e chiedere conferma quando l'utente lo chiede;
  le modifiche concordate ma non ancora eseguite vanno in `docs/next-build.md`.
- Font di sistema: metriche misurate per dispositivo in `metrics/*` (vedi `monkey.jungle`).
