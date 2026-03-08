#!/usr/bin/env python3
"""
Simulateur de Sharding pour Cyber-World
Focus : Stratégie de Range Partitioning uniquement
"""

from collections import defaultdict

# ── Configuration des Shards ────────────────────────────────
SHARDS = {
    0: 'inventory-db-0 (A-I)',
    1: 'inventory-db-1 (J-R)',
    2: 'inventory-db-2 (S-Z)',
}

# ── Stratégie : Range Partitioning ──────────────────────────
def range_shard(joueur_id: str) -> int:
    """Distribue les joueurs selon la première lettre de leur nom"""
    first = joueur_id[0].upper()
    
    if 'A' <= first <= 'I': 
        return 0
    elif 'J' <= first <= 'R': 
        return 1
    else: 
        return 2

# ── Test de la distribution ──────────────────────────────────
if __name__ == '__main__':
    joueurs = [
        'alice', 'bob', 'carlos', 'diana', 'eve', 
        'frank', 'grace', 'hector', 'iris', 'jack', 
        'kira', 'leo', 'max', 'nina', 'oscar', 
        'quentin', 'sam', 'victor', 'zara'
    ]

    print(f'=== STRATÉGIE : RANGE PARTITIONING ({len(joueurs)} joueurs) ===\n')
    
    distribution = defaultdict(list)

    for nom in joueurs:
        s_id = range_shard(nom)
        distribution[s_id].append(nom)
        print(f'  {nom:10} → Shard {s_id} ({SHARDS[s_id]})')

    print('\n' + '─' * 40)
    print('RÉSUMÉ DE LA DISTRIBUTION :')
    for s_id, membres in sorted(distribution.items()):
        print(f'Shard {s_id} : {len(membres)} joueurs {membres}')