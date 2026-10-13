# myTerrain — Application Mobile 📱 (Flutter)

Application mobile **myTerrain** pour joueurs et gérants de terrains de football (Five) au Sénégal, développée avec **Flutter (Dart)**.

---

## 🌍 Environnements & Cibles API

| Environnement | Cible | Commande d'exécution / Build | URL API Backend |
| :--- | :--- | :--- | :--- |
| **develop** | Dev local | `flutter run` | `http://127.0.0.1:8000` *(via `adb reverse tcp:8000 tcp:8000`)* |
| **preprod** | **DigitalOcean** | `flutter run --dart-define=API_URL=https://staging-api.myterrain.sn` | `https://staging-api.myterrain.sn` |
| **prod** | **Serveur Réel** | `flutter build apk --release --dart-define=API_URL=https://api.myterrain.sn` | `https://api.myterrain.sn` |

---

## 🚀 Démarrage Rapide (Local)

### 1. Téléphone branché en USB (Développement local rapide) :
Activez le mode débogage USB sur votre téléphone Android, puis :
```bash
# Redirige le port 8000 du téléphone vers le backend local de votre PC
adb reverse tcp:8000 tcp:8000

# Lancer l'application
flutter pub get
flutter run
```

### 2. Tester directement contre le backend DigitalOcean (Préprod) :
Pas besoin d'avoir un serveur local qui tourne !
```bash
flutter run --dart-define=API_URL=https://staging-api.myterrain.sn
```

---

## 📦 Build APK Android

```bash
# APK Release de Préproduction (DigitalOcean) :
flutter build apk --release --dart-define=API_URL=https://staging-api.myterrain.sn

# APK Release de Production (Serveur réel) :
flutter build apk --release --dart-define=API_URL=https://api.myterrain.sn
```
Le fichier généré sera disponible dans `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🤖 CI / CD GitHub Actions

Le workflow `.github/workflows/build-apk.yml` compile automatiquement l'APK Android :
- **Sur push sur `preprod`** : compile un APK configuré pour DigitalOcean.
- **Sur push sur `main` ou tag `v*`** : compile un APK configuré pour la Production et crée une Release GitHub.
- **Lancement manuel** : vous pouvez choisir l'environnement et l'URL d'API dans l'onglet Actions de GitHub.

---

## 🔄 Git Workflow
- `develop` : Développement quotidien
- `preprod` : Validation et tests contre DigitalOcean
- `main` : Production réelle
