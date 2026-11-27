# Origine des sons

Deux sources, toutes deux sous licence CC0 1.0. Chaque fichier est converti en Ogg Vorbis par
ffmpeg : silence de tête coupé, volume normalisé (`loudnorm`, −18 LUFS). Crédits dans
`CREDITS.md`. Aucun fichier d’origine n’est utilisé deux fois.

- « 400 Sounds Pack » (WAV 16 bits, 44,1 kHz), Chequered Ink : les 30 premiers tirs, les cinq
  impacts et les sons de partie. La colonne « Sous-dossier du pack » donne son sous-dossier.
- Les 45 tirs suivants (T9.20) viennent de deux packs de Kenney Vleugels, récupérés sur leurs
  miroirs OpenGameArt (kenney.nl est refusé par le proxy du conteneur) : « 50 RPG sound effects »
  (<https://opengameart.org/content/50-rpg-sound-effects>, `RPGsounds_Kenney.zip`, `license.txt`
  de l’archive : CC0) et « Sci-fi Sounds » (<https://opengameart.org/content/sci-fi-sounds>,
  `sci-fi_sounds.zip`, `License.txt` de l’archive : CC0). La page de chaque pack affiche aussi
  « CC0 ». Le choix a été fait sur le nom, la durée et le niveau des fichiers, sans les écouter ;
  les familles `laser*`, `thruster*` et `engine*`, trop marquées science-fiction, sont écartées.

- Les 15 tirs des armes de fin de partie (T12.7) viennent de cinq packs CC0 d’OpenGameArt, licence lue
  sur la page de chaque pack (champ « License(s) » : CC0) le 27/11/2026 ; la conversion est la même
  (Ogg Vorbis mono 44,1 kHz) ; le choix s’est fait sur le nom, la durée et le niveau, sans écoute :
  « 20 Sword Sound Effects » de StarNinjas (<https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes>),
  « 150 Combat Sound Effects » (<https://opengameart.org/content/150-combat-sound-effects>),
  « 75 CC0 Breaking/Falling/Hit SFX » (<https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx>),
  « Magic Spell SFX » (<https://opengameart.org/content/magic-spell-sfx>) et « 80 CC0 RPG SFX »
  (<https://opengameart.org/content/80-cc0-rpg-sfx>). Aucun de ces fichiers n’est utilisé deux fois.

| Identifiant                      | Sous-dossier du pack           | Fichier d’origine                                             |
| -------------------------------- | ------------------------------ | ------------------------------------------------------------- |
| `tir`                            | Weapons                        | `shot_muffled.wav`                                            |
| `impact`                         | Combat and Gore                | `punch_2.wav`                                                 |
| `mort`                           | Combat and Gore                | `splat_quick.wav`                                             |
| `achat`                          | Items                          | `coins_gather_small.wav`                                      |
| `relance`                        | UI                             | `pop_2.wav`                                                   |
| `pv_bas`                         | UI                             | `synth_warning.wav`                                           |
| `debut_manche`                   | Musical Effects                | `brass_level_start.wav`                                       |
| `boss`                           | Musical Effects                | `horror_sting.wav`                                            |
| `victoire`                       | Musical Effects                | `brass_level_complete.wav`                                    |
| `defaite`                        | Musical Effects                | `brass_defeated.wav`                                          |
| `tir_lame_de_fil`                | Weapons                        | `sword_slice.wav`                                             |
| `tir_faucille_a_ressort`         | Combat and Gore                | `swipe.wav`                                                   |
| `tir_disque_scie`                | Machines                       | `razor_buzz.wav`                                              |
| `tir_moulinet_de_cuivre`         | Other                          | `whoosh_1.wav`                                                |
| `tir_guillotine_a_vapeur`        | Machines                       | `hydraulic_down.wav`                                          |
| `tir_tourbillon_d_acier`         | Other                          | `whoosh_2.wav`                                                |
| `tir_arbalete_de_bureau`         | Other                          | `elastic_twang.wav`                                           |
| `tir_chausse_trape`              | Other                          | `snap.wav`                                                    |
| `tir_carreau_ricochet`           | Materials                      | `metal_blunt_tap.wav`                                         |
| `tir_herse_de_ressorts`          | Materials                      | `wood_small_hollow.wav`                                       |
| `tir_baliste_de_guet`            | Materials                      | `cork_stabbed.wav`                                            |
| `tir_pluie_d_aiguilles`          | Other                          | `finger_click.wav`                                            |
| `tir_etincelle_runique`          | UI                             | `sci_fi_select.wav`                                           |
| `tir_orbe_de_brume`              | Other                          | `ghost_long.wav`                                              |
| `tir_chaine_d_arcanes`           | UI                             | `sci_fi_hover_high.wav`                                       |
| `tir_cercle_de_givre`            | Environment                    | `ice_in_water.wav`                                            |
| `tir_nova_d_ambre`               | Other                          | `light_match.wav`                                             |
| `tir_tempete_astrale`            | Materials                      | `glass_ping_big.wav`                                          |
| `tir_bombarde_de_poche`          | Environment                    | `air_burst.wav`                                               |
| `tir_petard_de_rempart`          | Combat and Gore                | `kick.wav`                                                    |
| `tir_trebuchet_de_chambre`       | Weapons                        | `harsh_thud.wav`                                              |
| `tir_mine_de_forge`              | Materials                      | `metal_clang.wav`                                             |
| `tir_canon_de_cloche`            | Materials                      | `pottery_clang.wav`                                           |
| `tir_grande_bombarde`            | Weapons                        | `weapon_drop.wav`                                             |
| `tir_de_pipe`                    | Items                          | `tennis_ball_bounce_1.wav`                                    |
| `tir_sablier_fele`               | Environment                    | `clock_tock_only.wav`                                         |
| `tir_cornue_instable`            | Environment                    | `gurgling.wav`                                                |
| `tir_miroir_brise`               | Materials                      | `glass_ping_small.wav`                                        |
| `tir_vortex_de_verre`            | UI                             | `sci_fi_select_big.wav`                                       |
| `tir_horloge_folle`              | Environment                    | `clock_tick_only.wav`                                         |
| `tir_serpe_de_vigne`             | 50 RPG sound effects           | `knifeSlice.ogg`                                              |
| `tir_rasoir_tournoyant`          | 50 RPG sound effects           | `knifeSlice2.ogg`                                             |
| `tir_couperet_a_epines`          | 50 RPG sound effects           | `chop.ogg`                                                    |
| `tir_lame_de_brume`              | 50 RPG sound effects           | `drawKnife1.ogg`                                              |
| `tir_faucheuse_double`           | 50 RPG sound effects           | `drawKnife2.ogg`                                              |
| `tir_fleau_de_rasoirs`           | 50 RPG sound effects           | `drawKnife3.ogg`                                              |
| `tir_hache_de_garde`             | 50 RPG sound effects           | `cloth1.ogg`                                                  |
| `tir_scie_a_ruban`               | 50 RPG sound effects           | `clothBelt.ogg`                                               |
| `tir_moissonneuse_d_acier`       | 50 RPG sound effects           | `clothBelt2.ogg`                                              |
| `tir_javeline_de_jet`            | 50 RPG sound effects           | `cloth2.ogg`                                                  |
| `tir_trait_en_gerbe`             | 50 RPG sound effects           | `cloth3.ogg`                                                  |
| `tir_fleche_marquante`           | 50 RPG sound effects           | `cloth4.ogg`                                                  |
| `tir_arc_de_remparts`            | 50 RPG sound effects           | `beltHandle1.ogg`                                             |
| `tir_herse_de_pieux`             | 50 RPG sound effects           | `metalLatch.ogg`                                              |
| `tir_lance_epineuse`             | 50 RPG sound effects           | `metalClick.ogg`                                              |
| `tir_carquois_en_rafale`         | 50 RPG sound effects           | `beltHandle2.ogg`                                             |
| `tir_mur_de_pointes`             | 50 RPG sound effects           | `bookClose.ogg`                                               |
| `tir_couronne_de_pointes`        | 50 RPG sound effects           | `bookOpen.ogg`                                                |
| `tir_rune_de_veille`             | Sci-fi Sounds                  | `forceField_000.ogg`                                          |
| `tir_eclat_siphonneur`           | Sci-fi Sounds                  | `forceField_001.ogg`                                          |
| `tir_lueur_vagabonde`            | Sci-fi Sounds                  | `forceField_002.ogg`                                          |
| `tir_prisme_de_faille`           | Sci-fi Sounds                  | `forceField_003.ogg`                                          |
| `tir_orage_en_cage`              | 50 RPG sound effects           | `bookFlip1.ogg`                                               |
| `tir_couronne_d_etoiles`         | 50 RPG sound effects           | `bookFlip2.ogg`                                               |
| `tir_vasque_d_arcanes`           | Sci-fi Sounds                  | `forceField_004.ogg`                                          |
| `tir_nuee_d_etincelles`          | 50 RPG sound effects           | `bookFlip3.ogg`                                               |
| `tir_nova_celeste`               | 50 RPG sound effects           | `handleCoins2.ogg`                                            |
| `tir_baril_a_retardement`        | 50 RPG sound effects           | `metalPot1.ogg`                                               |
| `tir_maillet_de_rempart`         | 50 RPG sound effects           | `metalPot2.ogg`                                               |
| `tir_catapulte_a_contrepoids`    | 50 RPG sound effects           | `doorClose_1.ogg`                                             |
| `tir_obusier_de_breche`          | Sci-fi Sounds                  | `explosionCrunch_000.ogg`                                     |
| `tir_braise_de_siege`            | Sci-fi Sounds                  | `lowFrequency_explosion_001.ogg`                              |
| `tir_ecrasement_de_tour`         | Sci-fi Sounds                  | `lowFrequency_explosion_000.ogg`                              |
| `tir_champ_de_ruines`            | Sci-fi Sounds                  | `explosionCrunch_001.ogg`                                     |
| `tir_salve_du_rempart`           | 50 RPG sound effects           | `doorClose_2.ogg`                                             |
| `tir_colosse_de_pierre`          | 50 RPG sound effects           | `metalPot3.ogg`                                               |
| `tir_urne_des_ombres`            | 50 RPG sound effects           | `creak1.ogg`                                                  |
| `tir_pacte_de_sang`              | Sci-fi Sounds                  | `slime_000.ogg`                                               |
| `tir_engrenage_jumeau`           | 50 RPG sound effects           | `creak2.ogg`                                                  |
| `tir_serment_brise`              | 50 RPG sound effects           | `creak3.ogg`                                                  |
| `tir_archere_fantome`            | 50 RPG sound effects           | `handleSmallLeather.ogg`                                      |
| `tir_miroir_de_discorde`         | Sci-fi Sounds                  | `impactMetal_000.ogg`                                         |
| `tir_coupe_d_oubli`              | 50 RPG sound effects           | `handleSmallLeather2.ogg`                                     |
| `tir_legion_de_cendre`           | 50 RPG sound effects           | `dropLeather.ogg`                                             |
| `tir_tempete_de_malefices`       | 50 RPG sound effects           | `doorOpen_1.ogg`                                              |
| `tir_lame_des_aieux`             | Sword (20 Sword Sound Effects) | `sword.7.ogg`                                                 |
| `tir_ouragan_de_lames`           | 150 Combat Sound Effects       | `knife_slice2_48kHz_16bit_0.56s_d1b73212_s03.wav`             |
| `tir_faux_du_dernier_jour`       | Sword (20 Sword Sound Effects) | `sword.10.ogg`                                                |
| `tir_carquois_des_ancetres`      | 150 Combat Sound Effects       | `Shoot_03_s01.wav`                                            |
| `tir_epine_de_mille_ans`         | 75 CC0 Breaking/Falling/Hit    | `bfh1_wood_breaking_04.ogg`                                   |
| `tir_pique_du_souverain`         | 150 Combat Sound Effects       | `HeavyShot_02_s01.wav`                                        |
| `tir_sceptre_des_astres`         | Magic Spell SFX                | `magical_3.ogg`                                               |
| `tir_sablier_d_aurore`           | Magic Spell SFX                | `magical_5.ogg`                                               |
| `tir_oeil_du_firmament`          | Magic Spell SFX                | `magical_6_0.ogg`                                             |
| `tir_catapulte_des_anciens`      | 75 CC0 Breaking/Falling/Hit    | `bfh1_rock_falling_06.ogg`                                    |
| `tir_lance_braise_du_conquerant` | 150 Combat Sound Effects       | `explosion_crunch_003_48kHz_16bit_1.55s_4b973e9c_s04.wav`     |
| `tir_canon_du_dernier_rempart`   | 150 Combat Sound Effects       | `low_frequency_explosion_000_48kHz_16bit_2s_84586419_s04.wav` |
| `tir_urne_des_mille_ombres`      | 80 CC0 RPG SFX                 | `creature_monster_04.ogg`                                     |
| `tir_pendule_du_desordre`        | 80 CC0 RPG SFX                 | `spell_fire_07.ogg`                                           |
| `tir_couronne_du_vide`           | 150 Combat Sound Effects       | `GravityBomb_02_s01.wav`                                      |
| `impact_tranchant`               | Weapons                        | `sword_clash.wav`                                             |
| `impact_percant`                 | Combat and Gore                | `crunch_quick.wav`                                            |
| `impact_magique`                 | UI                             | `synth_process_complete.wav`                                  |
| `impact_siege`                   | Combat and Gore                | `punch_3.wav`                                                 |
| `impact_chaos`                   | Combat and Gore                | `squelching_2.wav`                                            |
| `ambiance`                       | —                              | aucun : silence de substitution (1)                           |

(1) Le pack n’a pas de boucle de fond : `ambient_wind` (8,6 s) a un raccord de boucle qui peut
claquer, et rien n’est musical. Musique d’ambiance reportée par Phil le 25/11/2026.
