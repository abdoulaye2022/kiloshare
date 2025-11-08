# Configuration Google Cloud Storage pour KiloShare

## Buckets séparés par environnement

⚠️ **Important** : Le système utilise deux buckets différents pour séparer les données :
- **Développement** : `kiloshare-dev`
- **Production** : `kiloshare-prod`

La sélection du bucket se fait automatiquement selon la variable `ENVIRONMENT` dans `.env`.

## Étapes de configuration

### 1. Créer un projet Google Cloud

1. Allez sur [Google Cloud Console](https://console.cloud.google.com/)
2. Créez un nouveau projet ou sélectionnez un projet existant
3. Notez le **Project ID** (ex: `kiloshare`)

### 2. Activer l'API Cloud Storage

1. Dans la console, allez dans **APIs & Services** > **Library**
2. Recherchez "Cloud Storage API"
3. Cliquez sur **Enable**

### 3. Créer les buckets (DEV et PROD)

Répétez ces étapes pour chaque bucket :

#### Bucket de développement : `kiloshare-dev`

1. Allez dans **Cloud Storage** > **Buckets**
2. Cliquez sur **Create Bucket**
3. Nom du bucket: `kiloshare-dev`
4. Région: Choisissez la région proche de vous (ex: `us-east1` pour l'Amérique du Nord)
5. Classe de stockage: **Standard**
6. Contrôle d'accès: **Fine-grained** (accès au niveau de l'objet)
7. Cliquez sur **Create**

#### Bucket de production : `kiloshare-prod`

Répétez les mêmes étapes avec le nom `kiloshare-prod`

### 4. Configurer les permissions publiques

Pour permettre l'accès public aux images :

1. Sélectionnez votre bucket
2. Allez dans l'onglet **Permissions**
3. Cliquez sur **Grant Access**
4. Nouveau principal: `allUsers`
5. Rôle: **Storage Object Viewer**
6. Cliquez sur **Save**

### 5. Créer un compte de service

1. Allez dans **IAM & Admin** > **Service Accounts**
2. Cliquez sur **Create Service Account**
3. Nom: `kiloshare-storage`
4. Description: `Service account for KiloShare image uploads`
5. Cliquez sur **Create and Continue**
6. Rôle: Sélectionnez **Storage Admin** (ou **Storage Object Admin** pour plus de sécurité)
7. Cliquez sur **Continue** puis **Done**

### 6. Créer une clé JSON

1. Cliquez sur le compte de service que vous venez de créer
2. Allez dans l'onglet **Keys**
3. Cliquez sur **Add Key** > **Create new key**
4. Type: **JSON**
5. Cliquez sur **Create**
6. Le fichier JSON sera téléchargé automatiquement

### 7. Configurer l'application

1. Copiez le fichier JSON téléchargé vers `/api/config/gcs-service-account.json`
2. Mettez à jour le fichier `/api/.env` :

```bash
GCS_PROJECT_ID=kiloshare-8f7fa  # Votre Project ID (trouvé dans Google Cloud Console)
GCS_BUCKET_NAME_DEV=kiloshare-dev
GCS_BUCKET_NAME_PROD=kiloshare-prod
GCS_KEY_FILE=config/gcs-service-account.json
```

3. Pour l'app Flutter, mettez à jour `/app/.env` :

```bash
GCS_PROJECT_ID=kiloshare-8f7fa
GCS_BUCKET_NAME=kiloshare-dev  # En développement
# En production, utilisez : kiloshare-prod
```

**Note** : Le bucket sera sélectionné automatiquement selon `ENVIRONMENT=development` ou `ENVIRONMENT=production`

### 8. Permissions du fichier

Assurez-vous que le fichier de clé a les bonnes permissions :

```bash
chmod 600 /api/config/gcs-service-account.json
```

## Structure des dossiers dans les buckets

### Bucket de développement (`kiloshare-dev`)
```
kiloshare-dev/
├── trips/
│   ├── 1/
│   │   ├── trip_1_0_1234567890.jpg
│   │   └── trip_1_1_1234567891.jpg
│   └── 2/
│       └── trip_2_0_1234567892.jpg
├── avatars/
│   ├── 1/
│   │   └── 1234567890.jpg
│   └── 2/
│       └── 1234567891.jpg
└── delivery_confirmations/
    └── booking_1/
        └── 1234567890_0.jpg
```

### Bucket de production (`kiloshare-prod`)
Même structure que le bucket de développement.

## URLs des images

### Développement
Les images seront accessibles via :
```
https://storage.googleapis.com/kiloshare-dev/trips/1/trip_1_0_1234567890.jpg
https://storage.googleapis.com/kiloshare-dev/avatars/1/1234567890.jpg
```

### Production
```
https://storage.googleapis.com/kiloshare-prod/trips/1/trip_1_0_1234567890.jpg
https://storage.googleapis.com/kiloshare-prod/avatars/1/1234567890.jpg
```

## Sécurité

- ⚠️ **NE JAMAIS** commiter le fichier `gcs-service-account.json` sur Git
- Le fichier est déjà dans `.gitignore`
- En production, utilisez des variables d'environnement ou des secrets managers

## Coûts

Google Cloud Storage propose une offre gratuite :
- 5 GB de stockage standard gratuit par mois
- 1 GB de trafic sortant gratuit par mois vers l'Amérique du Nord

Au-delà :
- Stockage : ~0.020$ par GB/mois
- Trafic sortant : Variable selon la région

## Migration depuis Cloudinary

Les anciennes images Cloudinary ne seront pas migrées automatiquement. Vous avez deux options :

1. **Migration progressive** : Les anciennes URLs Cloudinary continueront de fonctionner. Les nouvelles images utilisent GCS.
2. **Migration complète** : Télécharger toutes les images Cloudinary et les uploader vers GCS (script à créer si besoin).

## Support

En cas de problème :
- Vérifiez les logs : `tail -f /api/logs/error.log`
- Vérifiez les permissions du bucket
- Vérifiez que l'API Cloud Storage est activée
- Vérifiez que le compte de service a les bonnes permissions
