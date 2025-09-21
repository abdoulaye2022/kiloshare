# KiloShare Web

Site web Next.js 15 pour KiloShare - Plateforme de partage d'espace bagages

## 🚀 Démarrage rapide

1. **Installation des dépendances**
   ```bash
   npm install
   ```

2. **Configuration environnement**
   - Le fichier `.env.local` est déjà configuré avec les bonnes valeurs
   - Backend API : `http://localhost:8080`
   - Web App : `http://localhost:3000`

3. **Lancement en développement**
   ```bash
   npm run dev
   ```

4. **Accès**
   - Site web : [http://localhost:3000](http://localhost:3000)
   - Vérification email : [http://localhost:3000/verify-email](http://localhost:3000/verify-email)

## 📧 Test de vérification email

Pour tester la vérification email :

1. Créez un compte via l'app mobile Flutter
2. Récupérez le token depuis `api/logs/dev_emails.json`
3. Accédez à : `http://localhost:3000/verify-email?token=VOTRE_TOKEN`

## 🛠️ Scripts disponibles

- `npm run dev` - Serveur de développement
- `npm run build` - Build de production
- `npm start` - Serveur de production
- `npm run lint` - Vérification du code

## 🎨 Technologies utilisées

- **Next.js 15** - Framework React
- **TypeScript** - Typage statique
- **Tailwind CSS** - Framework CSS
- **Lucide React** - Icônes
- **React Hooks** - Gestion d'état

## 📱 Fonctionnalités

- ✅ Page d'accueil avec présentation de l'app
- ✅ Page de vérification d'email
- ✅ Design responsive
- ✅ Intégration API backend
- ✅ Interface moderne et attractive

## 🔗 Liens utiles

- Page d'accueil : `/`
- Vérification email : `/verify-email?token=TOKEN`
- API Backend : `http://localhost:8080/api/v1`