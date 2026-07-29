# Compile Queue

Objectif : obtenir un build propre puis faire afficher `value=7`.

Contraintes :

- lance les builds avec `<leader>cb` ;
- navigue uniquement avec `:cfirst`, `:cnext` et `:cprev` ;
- corrige une cause racine à la fois ;
- n'utilise pas `make clean` avant la validation finale.

Commande de validation :

```sh
make clean all
./compile_queue 7
```

La sortie attendue est `value=7` et le code retour doit être zéro. Le projet
contient cinq causes indépendantes réparties entre compilation et édition de
liens.
