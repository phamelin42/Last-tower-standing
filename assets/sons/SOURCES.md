# Origine des sons

Chaque fichier est extrait du « 400 Sounds Pack » (WAV 16 bits, 44,1 kHz), converti en Ogg
Vorbis par ffmpeg : silence de tête coupé, volume normalisé (`loudnorm`, −18 LUFS). Crédits dans
`CREDITS.md`.

| Identifiant    | Sous-dossier du pack | Fichier d’origine                   |
| -------------- | -------------------- | ----------------------------------- |
| `tir`          | Weapons              | `shot_muffled.wav`                  |
| `impact`       | Combat and Gore      | `punch_2.wav`                       |
| `mort`         | Combat and Gore      | `splat_quick.wav`                   |
| `achat`        | Items                | `coins_gather_small.wav`            |
| `relance`      | UI                   | `pop_2.wav`                         |
| `pv_bas`       | UI                   | `synth_warning.wav`                 |
| `debut_manche` | Musical Effects      | `brass_level_start.wav`             |
| `boss`         | Musical Effects      | `horror_sting.wav`                  |
| `victoire`     | Musical Effects      | `brass_level_complete.wav`          |
| `defaite`      | Musical Effects      | `brass_defeated.wav`                |
| `ambiance`     | —                    | aucun : silence de substitution (1) |

(1) Le pack n’a pas de boucle de fond : `ambient_wind` (8,6 s) a un raccord de boucle qui peut
claquer, et rien n’est musical. Le fichier `ambiance.ogg` reste à fournir.
