# 🚨 ACTIONS DE SÉCURITÉ IMMÉDIATES REQUISES

## PRIORITÉ CRITIQUE - À FAIRE MAINTENANT

### 1. Rotation des Clés Cloudinary Exposées

**CLÉS COMPROMISES :**
- Cloud Name: `dvqisegwj`
- API Key: `821842469494291`  
- API Secret: `YgVWPlhwCEuo9t8nRkwsfjzXcSI`

#### Actions Immédiates :

1. **Se connecter à Cloudinary Dashboard**
   - URL : https://cloudinary.com/console
   - Compte : Votre compte KiloShare

2. **Générer de nouvelles clés**
   - Aller dans Settings → Security
   - Cliquer sur "Regenerate API Secret"
   - Noter les nouvelles valeurs

3. **Mettre à jour les fichiers .env**

**Backend (.env) :**
```env
CLOUDINARY_CLOUD_NAME=nouveau_cloud_name
CLOUDINARY_API_KEY=nouvelle_api_key
CLOUDINARY_API_SECRET=nouveau_api_secret
```

**Mobile (.env) :**
```env
CLOUDINARY_CLOUD_NAME=nouveau_cloud_name
CLOUDINARY_API_KEY=nouvelle_api_key
CLOUDINARY_API_SECRET=nouveau_api_secret
```

4. **Révoquer les anciennes clés**
   - Dans Cloudinary Dashboard
   - S'assurer que les anciennes clés ne fonctionnent plus

### 2. Vérifier les Autres Clés

#### Firebase
- **Status :** Potentiellement exposée
- **Clé :** `AIzaSyAos_M9aCOATa0GXDPqwDqVjSYXQrnb9IY`
- **Action :** Régénérer dans Firebase Console si nécessaire

#### Stripe  
- **Clé publique :** `pk_test_51R4ZsgFjNfCheyJ86GxLtaaSXb0E8vulUuqqbUKve7HgehVANW81T1fOI2CfptjQB7o3RNDBjquYeSYuDq3dPk3S009XPyrZFX`
- **Action :** Vérifier dans Stripe Dashboard

### 3. Redéployer avec Nouvelles Clés

```bash
# Backend
cd backend
# Mettre à jour .env avec nouvelles clés
php -S 127.0.0.1:8000 -t public

# Mobile  
cd mobile
# Mettre à jour .env avec nouvelles clés
flutter run

# Web
cd web
# Vérifier .env.local
npm run dev
```

### 4. Vérifier le Fonctionnement

- [ ] Upload d'images fonctionne (backend)
- [ ] Upload d'images fonctionne (mobile)  
- [ ] Affichage d'images fonctionne (web)
- [ ] Pas d'erreurs Cloudinary dans les logs

### 5. Confirmer la Sécurité

```bash
# Vérifier qu'aucune clé n'est hardcodée
grep -r "821842469494291" .
grep -r "YgVWPlhwCEuo9t8nRkwsfjzXcSI" .
grep -r "dvqisegwj" . --exclude-dir=".git" --exclude="*.md"
```

**Résultat attendu :** Aucun match dans le code source

## TIMELINE

- **0-30 min :** Rotation clés Cloudinary
- **30-60 min :** Mise à jour fichiers .env  
- **60-90 min :** Redéploiement et tests
- **90-120 min :** Vérification complète

## CONTACT D'URGENCE

Si problème durant la rotation :
1. Revenir aux anciennes clés temporairement
2. Investiguer le problème  
3. Recommencer la rotation une fois résolu

---

## ✅ CHECKLIST FINALE

- [ ] Nouvelles clés Cloudinary générées
- [ ] Fichiers .env mis à jour (backend + mobile)
- [ ] Applications redéployées  
- [ ] Upload d'images testé et fonctionnel
- [ ] Anciennes clés révoquées
- [ ] Aucune trace des anciennes clés dans le code
- [ ] GitGuardian ne détecte plus d'alertes

**Une fois terminé, supprimer ce fichier pour éviter de laisser des traces des anciennes clés.**