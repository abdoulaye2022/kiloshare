# 🛠️ Résolution des Problèmes d'Import

## Erreur DEFINER - Access Denied

### 🚨 Problème
```
#1227 - Access denied; you need (at least one of) the SUPER or SET_ANY_DEFINER privilege(s)
```

### 💡 Cause
Les triggers et procédures stockées exportées contiennent des `DEFINER=root@localhost` qui ne sont pas autorisés sur les serveurs de production/hébergement partagé.

### ✅ Solutions

#### Solution 1 : Utiliser le Schéma Production (Recommandé)
```bash
# Générer le schéma nettoyé
./export_production.sh

# Importer le schéma production
mysql -u your_user -p your_database < schema_production.sql
```

#### Solution 2 : Nettoyer Manuellement
Si vous avez déjà le fichier `schema.sql`, nettoyez-le :

```bash
# Supprimer tous les DEFINER
sed 's/DEFINER=[^[:space:]]*[[:space:]]*//g' schema.sql > schema_clean.sql

# Importer le fichier nettoyé
mysql -u your_user -p your_database < schema_clean.sql
```

#### Solution 3 : Via phpMyAdmin
1. Ouvrez `schema_production.sql` dans un éditeur de texte
2. Copiez tout le contenu
3. Collez dans l'onglet SQL de phpMyAdmin
4. Exécutez

### 🔧 Prévention

Utilisez toujours `schema_production.sql` pour les déploiements :
- ✅ Compatible tous hébergeurs
- ✅ Pas de restrictions DEFINER
- ✅ Optimisé pour production

## Autres Erreurs Courantes

### Erreur de Charset
```
#1273 - Unknown collation: 'utf8mb4_0900_ai_ci'
```

**Solution :**
```sql
-- Remplacer par une collation compatible
utf8mb4_unicode_ci
```

### Tables Already Exist
```
#1050 - Table 'users' already exists
```

**Solution :**
```sql
-- Ajouter IF NOT EXISTS (déjà inclus dans schema_production.sql)
CREATE TABLE IF NOT EXISTS `users` ...
```

### Foreign Key Constraints
```
#1217 - Cannot delete or update a parent row: a foreign key constraint fails
```

**Solution :**
```sql
-- Désactiver temporairement (déjà inclus dans schema_production.sql)
SET FOREIGN_KEY_CHECKS = 0;
-- Vos imports ici
SET FOREIGN_KEY_CHECKS = 1;
```

## 📋 Checklist Import Production

- [ ] Utiliser `schema_production.sql`
- [ ] Vérifier que la base de données est vide ou faire un backup
- [ ] Tester l'import sur un environnement de test d'abord
- [ ] Vérifier les permissions de l'utilisateur MySQL
- [ ] Confirmer la version MySQL compatible (5.7+)

## 🆘 En Cas de Problème

1. **Backup first** : Toujours faire une sauvegarde
2. **Test local** : Tester l'import en local d'abord
3. **Logs** : Vérifier les logs MySQL pour plus de détails
4. **Support** : Contacter le support de votre hébergeur

## 📞 Commandes Utiles

```bash
# Vérifier la version MySQL
mysql --version

# Voir les privilèges de l'utilisateur
SHOW GRANTS FOR 'username'@'hostname';

# Voir les bases de données
SHOW DATABASES;

# Voir les tables
USE your_database;
SHOW TABLES;

# Vérifier l'intégrité
CHECK TABLE table_name;
```