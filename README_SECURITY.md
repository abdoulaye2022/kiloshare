# 🔒 Sécurité KiloShare - Guide Rapide

## ⚡ Actions Immédiates pour Tout Développeur

### 1. Configuration Initiale
```bash
# Copier le fichier d'environnement
cp api/.env.example api/.env

# Éditer avec vos vraies clés (JAMAIS commiter ce fichier)
nano api/.env

# Activer le hook de sécurité
ln -sf ../../.githooks/pre-commit .git/hooks/pre-commit
```

### 2. Vérification Rapide
```bash
# Lancer la vérification automatique
./scripts/security-check.sh

# Vérifier qu'aucun secret n'est tracké
git status --ignored
```

## 📋 Fichiers Protégés

### ✅ SÉCURISÉ (dans .gitignore)
- `.env*` - Variables d'environnement
- `firebase-service-account.json` - Clés Firebase
- `*.key`, `*.pem` - Certificats
- `*secret*.md` - Documentation sensible

### ⚠️ À SURVEILLER
- `config/settings.php` - Utilise `$_ENV` ✓
- `config/database.php` - Utilise `$_ENV` ✓

## 🚨 En Cas de Fuite

1. **RÉVOQUER** immédiatement les clés
2. **GÉNÉRER** de nouvelles clés
3. **METTRE À JOUR** tous les environnements
4. **REDÉMARRER** les services

👉 **Voir EMERGENCY_SECURITY.md pour la procédure complète**

## 🛠️ Outils de Sécurité

- **Pre-commit Hook** : Détecte automatiquement les secrets
- **Script de Vérification** : `./scripts/security-check.sh`
- **Documentation** : `SECURITY.md` (guide complet)

## ⚡ Règles d'Or

1. **JAMAIS** commiter de fichiers `.env`
2. **TOUJOURS** utiliser `$_ENV['CLE']` dans le code
3. **VÉRIFIER** avec le script avant de push
4. **RÉVOQUER** en cas de doute

---
💡 **En cas de problème** : Voir `EMERGENCY_SECURITY.md` ou contacter l'équipe dev