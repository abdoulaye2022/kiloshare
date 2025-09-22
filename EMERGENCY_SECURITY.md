# 🚨 PROCÉDURE D'URGENCE SÉCURITÉ

## Si des clés secrètes ont été exposées sur Git

### ⚡ ACTION IMMÉDIATE (dans les 5 premières minutes)

1. **RÉVOQUER TOUTES LES CLÉS** exposées immédiatement :

#### Stripe
- Aller sur https://dashboard.stripe.com/apikeys
- Cliquer "Reveal" sur la clé secrète exposée
- Cliquer "Delete" ou "Roll" pour la révoquer
- Générer une nouvelle clé immédiatement

#### Firebase
- Aller sur https://console.firebase.google.com/
- Projet > Paramètres > Comptes de service
- Supprimer le compte de service compromis
- Créer un nouveau compte de service

#### Database
- Changer immédiatement le mot de passe de la base de données
- Vérifier les connexions actives
- Révoquer les sessions suspectes

### 📋 CHECKLIST DE RÉVOCATION

```bash
# 1. Stripe (SI EXPOSÉ)
[ ] Révoquer les clés secrètes sur dashboard.stripe.com
[ ] Générer de nouvelles clés
[ ] Mettre à jour .env sur tous les serveurs
[ ] Redémarrer les services

# 2. Firebase (SI EXPOSÉ)
[ ] Supprimer le compte de service compromis
[ ] Créer un nouveau compte de service
[ ] Télécharger le nouveau fichier JSON
[ ] Mettre à jour la configuration serveur
[ ] Redémarrer les services

# 3. Base de données (SI EXPOSÉE)
[ ] Changer le mot de passe DB
[ ] Vérifier les logs de connexion
[ ] Mettre à jour .env
[ ] Redémarrer les connexions

# 4. JWT Secret (SI EXPOSÉ)
[ ] Générer un nouveau secret (32+ caractères)
[ ] Mettre à jour .env
[ ] Redémarrer les services (⚠️ déconnectera tous les utilisateurs)

# 5. Email/SMTP (SI EXPOSÉ)
[ ] Changer le mot de passe email
[ ] Mettre à jour .env
[ ] Tester l'envoi d'emails
```

### 🔍 VÉRIFICATION DES DÉGÂTS

```bash
# Vérifier l'historique Git pour voir quand la clé a été exposée
git log --follow -p -- chemin/vers/fichier/sensible

# Chercher tous les commits contenant la clé
git log --all --grep="clé_exposée"

# Vérifier qui a accès au repository
git remote -v
```

### 📞 CONTACTS D'URGENCE

- **Stripe Support** : https://support.stripe.com/
- **Firebase Support** : https://firebase.google.com/support/
- **Développeur Principal** : Mohamed Ahmed

### 🛠️ COMMANDES DE NETTOYAGE GIT

```bash
# SI LA CLÉ EST DANS L'HISTORIQUE GIT (DANGEREUX!)

# Option 1: Supprimer le fichier de tout l'historique
git filter-branch --force --index-filter \
'git rm --cached --ignore-unmatch chemin/vers/fichier' \
--prune-empty --tag-name-filter cat -- --all

# Option 2: Réécrire l'historique avec BFG Repo-Cleaner
# Télécharger: https://rtyley.github.io/bfg-repo-cleaner/
java -jar bfg.jar --delete-files nomfichier.json
git reflog expire --expire=now --all && git gc --prune=now --aggressive

# Option 3: Remplacer le contenu dans l'historique
git filter-branch --tree-filter \
'if [ -f chemin/vers/fichier ]; then sed -i "s/ancienne_clé/REDACTED/g" chemin/vers/fichier; fi' HEAD

# FORCER la mise à jour du remote (⚠️ DESTRUCTIF)
git push origin --force --all
git push origin --force --tags
```

### 🚨 APRÈS LE NETTOYAGE

1. **Informer l'équipe** du changement de clés
2. **Mettre à jour tous les environnements** (dev, staging, prod)
3. **Vérifier les logs** pour détecter une utilisation malveillante
4. **Documenter l'incident** pour éviter la répétition
5. **Renforcer les procédures** de sécurité

### 📊 SURVEILLANCE POST-INCIDENT

```bash
# Surveiller les logs Stripe pour usage suspect
# Dashboard Stripe > Logs > Filtrer par dates

# Surveiller Firebase
# Console Firebase > Usage > Surveiller les pics d'activité

# Surveiller la base de données
# Vérifier les connexions et requêtes suspectes
```

### 🔒 PRÉVENTION FUTURE

- [ ] Activer les alertes de sécurité GitHub
- [ ] Configurer des hooks pre-commit pour détecter les secrets
- [ ] Utiliser des outils comme GitLeaks ou TruffleHog
- [ ] Formation équipe sur les bonnes pratiques
- [ ] Audit de sécurité mensuel

---

**⚠️ RAPPEL IMPORTANT** : En cas de doute, TOUJOURS révoquer d'abord, investiguer ensuite. Il vaut mieux une interruption de service temporaire qu'une faille de sécurité permanente.

**📱 URGENCE 24/7** : En cas d'incident critique en dehors des heures ouvrables, contacter immédiatement l'équipe de développement.