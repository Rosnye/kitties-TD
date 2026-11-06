extends RefCounted
## Datos de balance: torres, enemigos y mejoras. Edita aquí para equilibrar el juego.

const TOWERS := {
	"basic": {
		"name": "Gato Naranja", "cost": 40, "range": 120.0, "damage": 10.0,
		"rate": 1.5, "color": Color(0.95, 0.6, 0.2),
	},
	"yarn": {
		"name": "Gato Estambre", "cost": 100, "range": 110.0, "damage": 16.0,
		"rate": 0.7, "splash": 55.0, "color": Color(0.9, 0.35, 0.5),
	},
	"siamese": {
		"name": "Gato Siamés", "cost": 75, "range": 105.0, "damage": 3.0,
		"rate": 1.2, "slow": 0.5, "slow_time": 1.5, "color": Color(0.85, 0.8, 0.7),
	},
}

const ENEMIES := {
	"mouse": {"hp": 30.0, "speed": 70.0, "reward": 7, "damage": 1, "radius": 14.0, "color": Color(0.6, 0.6, 0.65)},
	"fast": {"hp": 18.0, "speed": 125.0, "reward": 8, "damage": 1, "radius": 11.0, "color": Color(0.7, 0.5, 0.35)},
	"rat": {"hp": 130.0, "speed": 45.0, "reward": 20, "damage": 2, "radius": 20.0, "color": Color(0.4, 0.35, 0.35)},
}

const UPGRADES := [
	{"id": "dmg", "name": "Garras afiladas", "desc": "+20% de daño en todas las torres"},
	{"id": "range", "name": "Ojos de gato", "desc": "+15% de alcance en todas las torres"},
	{"id": "rate", "name": "Café con leche", "desc": "+20% de velocidad de ataque"},
	{"id": "splash", "name": "Ovillo gigante", "desc": "+40% de radio de explosión del Gato Estambre"},
	{"id": "slow", "name": "Maullido hipnótico", "desc": "El Gato Siamés ralentiza más"},
	{"id": "bounty", "name": "Cazador nato", "desc": "+25% de monedas por enemigo"},
	{"id": "income", "name": "Granja de atún", "desc": "+30 monedas al terminar cada oleada"},
	{"id": "heal", "name": "Siesta", "desc": "+5 vidas"},
	{"id": "cash", "name": "Caja de croquetas", "desc": "+120 monedas ahora"},
	{"id": "discount", "name": "Rebajas", "desc": "Las torres cuestan 15% menos"},
]
