# Cloudinary Cleanup Cron Jobs

Ce répertoire contient les scripts de maintenance automatique pour la gestion optimale du quota Cloudinary de KiloShare.

## 📋 Vue d'ensemble

Le système de nettoyage automatique surveille et optimise l'utilisation de Cloudinary pour rester dans les limites du plan gratuit (25GB de stockage et bande passante par mois).

## 🔧 Scripts disponibles

### `cloudinary_cleanup.php` - Script principal
Script PHP pour la gestion des images Cloudinary avec plusieurs commandes :

#### Commandes disponibles :
```bash
# Nettoyage automatique (seulement si quotas > 75%)
php cloudinary_cleanup.php auto [--dry-run] [--verbose]

# Nettoyage forcé de toutes les vieilles images
php cloudinary_cleanup.php force [--dry-run] [--verbose]

# Vérification du statut des quotas
php cloudinary_cleanup.php check-quota [--verbose]

# Affichage des statistiques d'usage
php cloudinary_cleanup.php stats [--verbose]

# Génération d'un rapport mensuel
php cloudinary_cleanup.php report [--verbose]
```

#### Options :
- `--dry-run` : Affiche ce qui serait nettoyé sans rien supprimer
- `--verbose` : Affiche des informations détaillées
- `--help` : Affiche l'aide

### `setup_cron.sh` - Installation des tâches cron
Script bash pour installer automatiquement les tâches cron de maintenance.

```bash
./scripts/setup_cron.sh
```

### `remove_cron.sh` - Suppression des tâches cron  
Script bash pour supprimer les tâches cron installées.

```bash
./scripts/remove_cron.sh
```

## 📅 Planning des tâches automatiques

Une fois installées, les tâches cron s'exécutent selon ce planning :

| Tâche | Fréquence | Horaire | Description |
|-------|-----------|---------|-------------|
| **Nettoyage automatique** | Toutes les 6 heures | 00:00, 06:00, 12:00, 18:00 | Nettoie si quota > 75% |
| **Vérification quotas** | Quotidienne | 09:00 | Vérifie les quotas et alerte |
| **Statistiques hebdomadaires** | Hebdomadaire | Lundi 08:00 | Génère les stats de la semaine |
| **Rapport mensuel** | Mensuelle | 1er du mois 07:00 | Rapport complet du mois écoulé |

## 📊 Stratégie de nettoyage

### Nettoyage automatique (`auto`)
- Se déclenche seulement si stockage OU bande passante > 75%
- Supprime les images dans cet ordre de priorité :
  1. Images supprimées par les utilisateurs (30+ jours)
  2. Anciens documents KYC (180+ jours) 
  3. Photos de voyages anciens (365+ jours)
  4. Anciennes photos de colis (90+ jours)
  5. Preuves de livraison anciennes (180+ jours)

### Nettoyage forcé (`force`)
- Supprime toutes les images éligibles selon les critères d'âge
- Demande confirmation avant suppression
- Utilisé en cas d'urgence ou maintenance planifiée

## 📁 Fichiers de logs

Les logs sont sauvegardés dans `logs/` :

```
logs/
├── cloudinary_auto_cleanup.log      # Nettoyages automatiques
├── cloudinary_quota_check.log       # Vérifications quotidiennes des quotas
├── cloudinary_weekly_stats.log      # Statistiques hebdomadaires  
├── cloudinary_monthly_report.log    # Rapports mensuels
└── cloudinary_cleanup.log           # Logs généraux du service
```

## 🚀 Installation

1. **Installer les tâches cron :**
   ```bash
   cd /path/to/kiloshare/backend
   ./scripts/setup_cron.sh
   ```

2. **Vérifier l'installation :**
   ```bash
   crontab -l
   ```

3. **Tester le script :**
   ```bash
   php scripts/cloudinary_cleanup.php check-quota --verbose
   ```

## 🔍 Surveillance

### Vérification manuelle des quotas
```bash
php scripts/cloudinary_cleanup.php check-quota
```

### Test de nettoyage (sans suppression)
```bash
php scripts/cloudinary_cleanup.php auto --dry-run --verbose
```

### Génération d'un rapport
```bash
php scripts/cloudinary_cleanup.php report --verbose
```

## ⚠️ Seuils d'alerte

| Métrique | Seuil d'attention | Seuil critique | Action |
|----------|-------------------|----------------|---------|
| **Stockage** | 75% | 90% | Nettoyage automatique |
| **Bande passante** | 75% | 90% | Optimisation des transformations |

## 🛡️ Sécurité

- Les images critiques (avatars récents, KYC actifs) ne sont jamais supprimées automatiquement
- Système de confirmation pour les nettoyages forcés
- Logs détaillés de toutes les opérations
- Backup automatique des métadonnées avant suppression

## 🔧 Maintenance

### Désinstaller les tâches cron
```bash
./scripts/remove_cron.sh
```

### Modifier le planning
```bash
crontab -e
```

### Nettoyage des logs anciens
```bash
find logs/ -name "cloudinary_*.log" -mtime +90 -delete
```

## 📈 Monitoring

Le système génère automatiquement :
- **Alertes** en cas de dépassement des seuils
- **Statistiques** hebdomadaires d'utilisation  
- **Rapports** mensuels détaillés
- **Recommandations** d'optimisation

## 🚨 Résolution de problèmes

### Les tâches cron ne s'exécutent pas
1. Vérifier que le service cron est actif : `sudo service cron status`
2. Vérifier les permissions : `ls -la scripts/cloudinary_cleanup.php`
3. Tester manuellement : `php scripts/cloudinary_cleanup.php check-quota`

### Erreurs dans les logs
1. Vérifier les permissions sur le répertoire `logs/`
2. Contrôler la configuration Cloudinary dans `.env`
3. Tester la connexion base de données

### Quota dépassé malgré le nettoyage
1. Analyser le rapport mensuel pour identifier les gros consommateurs
2. Examiner les transformations d'images les plus utilisées
3. Considérer l'ajustement des stratégies de compression

---

**Note :** Ce système est conçu pour maximiser l'efficacité du plan gratuit Cloudinary. Pour des besoins plus importants, considérez la migration vers un plan payant.