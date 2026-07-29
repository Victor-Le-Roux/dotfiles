# Boucle de feedback C avec Neovim

Ce programme entraîne le principal écart entre ton workflow actuel et celui
d'un développeur senior : conserver une boucle stable entre modification,
compilation, diagnostic et exécution. Il utilise uniquement la configuration
existante.

## Protocole unique

1. Écris le scénario à reproduire et son résultat attendu avant de modifier le
   code.
2. Lance le build avec `<leader>cb`.
3. Traite les diagnostics comme une file : `:cfirst`, `:cnext`, `:cprev`.
   Corrige d'abord la cause susceptible de produire les erreurs suivantes.
4. Recompile immédiatement. N'utilise `make clean` que pour la validation
   finale.
5. Après un build réussi, crée le scénario avec
   `:OverseerShell ./binaire arguments`.
6. Ouvre `<leader>co`, sélectionne la tâche d'exécution, puis choisis `restart`
   pour rejouer exactement le même cas.
7. Après deux hypothèses infirmées, passe au débogueur : `F9` pose un
   breakpoint, `F5` démarre ou continue, `F10` à `F12` avancent dans le code.

Ne quitte pas Neovim pour rechercher une erreur déjà connue de quickfix et ne
retape pas une commande d'exécution pendant la même session.

## Rythme quotidien

Travaille cinq jours par semaine pendant six semaines :

- 10 minutes sur `compile_queue` pour automatiser build et quickfix ;
- 40 minutes sur ton projet réel avec le protocole ci-dessus ;
- 10 minutes sur `runtime_bug` ou `api_change`, puis validation complète.

Le vendredi, relance les trois exercices depuis leur état initial et mesure
uniquement leur durée totale. Aucun journal narratif n'est nécessaire.

| Semaine | Objectif |
| --- | --- |
| 1 | Naviguer exclusivement avec quickfix |
| 2 | Rejouer un scénario sans retaper sa commande |
| 3 | Séparer cause racine, cascade et warning |
| 4 | Utiliser DAP seulement sur un défaut reproductible |
| 5 | Propager une modification d'API entre plusieurs fichiers |
| 6 | Enchaîner build, cas limites et vérification mémoire |

## Lancer un benchmark

Depuis ce dépôt :

```sh
./training/start.sh compile_queue
./training/start.sh runtime_bug
./training/start.sh api_change
```

Le lanceur crée une copie jetable dans `/tmp`, affiche le chemin à ouvrir et
démarre le chronomètre. Dans le répertoire généré :

```sh
nvim .
./finish.sh
```

`finish.sh` affiche la durée sans conserver d'historique. Les consignes propres
à l'exercice sont dans son `README.md`.

## Critères de sortie

À la fin des six semaines :

- sauvegarde vers build lancé en moins de 2 secondes ;
- diagnostic vers fichier concerné en moins de 5 secondes ;
- build réussi vers scénario relancé en moins de 5 secondes ;
- aucun changement de terminal pour parcourir les erreurs ;
- réduction d'au moins 40 % du temps des trois benchmarks ;
- validation finale par build propre, cas limites et `valgrind` lorsque
  pertinent.
