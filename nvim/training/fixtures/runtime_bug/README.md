# Runtime Bug

Le projet compile déjà. Le scénario reproductible est :

```sh
./runtime_bug -8 -3 -5
```

Résultat attendu :

```text
min=-8 max=-3 sum=-16
```

Crée ce scénario avec `:OverseerShell`, puis rejoue la même tâche au lieu de
retaper la commande. Formule une hypothèse avant chaque modification. Après
deux hypothèses infirmées, utilise DAP.

Validation finale :

```sh
make test
valgrind --quiet --error-exitcode=42 ./runtime_bug -8 -3 -5
```
