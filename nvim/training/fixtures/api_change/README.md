# API Change

L'API actuelle limite une valeur entre zéro et une borne maximale :

```c
int	clamp_value(int value, int maximum);
```

Fais-la évoluer vers :

```c
int	clamp_value(int value, int minimum, int maximum);
```

Le programme doit accepter `value minimum maximum`. Utilise les diagnostics du
compilateur pour retrouver et adapter les appelants, sans recherche manuelle.

Validation finale :

```sh
make clean test
```

Les cas attendus couvrent une valeur sous la borne, dans l'intervalle et au-dessus.
