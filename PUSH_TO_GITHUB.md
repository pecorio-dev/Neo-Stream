# 🚀 Guide pour pousser le code sur GitHub

Ce guide explique comment supprimer tout le contenu actuel de votre repository GitHub `https://github.com/pecorio-dev/NEO-Stream` et le remplacer par le code de ce workspace.

## ⚠️ ATTENTION

Cette opération va **SUPPRIMER DÉFINITIVEMENT** tout le code actuellement sur GitHub. Assurez-vous d'avoir une sauvegarde si nécessaire !

---

## 📋 Étapes à suivre

### 1. Initialiser Git localement (si pas déjà fait)

```bash
# Vérifier si Git est initialisé
git status

# Si "fatal: not a git repository", initialiser :
git init
```

### 2. Configurer le remote GitHub

```bash
# Ajouter le remote (si pas déjà fait)
git remote add origin https://github.com/pecorio-dev/NEO-Stream.git

# Ou mettre à jour le remote existant
git remote set-url origin https://github.com/pecorio-dev/NEO-Stream.git

# Vérifier
git remote -v
```

### 3. Créer un .gitignore

```bash
cat > .gitignore << 'EOF'
# Android
*.apk
*.aab
*.ap_
*.dex
*.class
bin/
gen/
out/
captures/
.externalNativeBuild
.cxx
*.log

# Gradle
.gradle/
build/
!gradle-wrapper.jar

# Local configuration
local.properties
*.jks
*.keystore

# IDE
.idea/
*.iml
.DS_Store

# Kotlin
.kotlin/

# Temporary files
tmp_rovodev_*
app/argparse
app/extractor code
app/json
app/logging
app/os
app/player code
app/proguard-rules.pro
app/requests
EOF
```

### 4. Ajouter tous les fichiers

```bash
# Ajouter tous les fichiers (sauf ceux dans .gitignore)
git add .

# Vérifier les fichiers ajoutés
git status
```

### 5. Créer le premier commit

```bash
git commit -m "Initial commit - NeoStream Android App (Mobile + TV)

- Application de streaming Films & Séries
- Support Mobile (Compose) + Android TV (Leanback)
- ExoPlayer (Media3) pour la lecture vidéo
- Room Database (Favoris, Comptes, Progression)
- Ktor Client pour l'API
- Coil3 pour les images
- DNS-over-HTTPS pour bypass FAI
- Architecture MVVM + Repository Pattern
"
```

### 6. Forcer le push (⚠️ SUPPRIME TOUT sur GitHub)

```bash
# Option 1 : Force push (DANGER - écrase l'historique GitHub)
git push -f origin main

# Si votre branche principale s'appelle "master" :
git push -f origin master
```

### 7. Alternative plus sûre (créer une nouvelle branche)

Si vous voulez conserver l'ancien code sur GitHub :

```bash
# Créer une branche de sauvegarde sur GitHub d'abord
# (Via l'interface GitHub ou en CLI)

# Puis push sur main
git branch -M main
git push -u origin main
```

---

## 🔑 Authentification GitHub

### Avec Personal Access Token (Recommandé)

1. **Créer un token** : https://github.com/settings/tokens
   - Cocher : `repo` (full control)
   - Générer et copier le token

2. **Lors du push** :
   ```bash
   Username: pecorio-dev
   Password: <VOTRE_TOKEN>
   ```

3. **Ou configurer le remote avec token** :
   ```bash
   git remote set-url origin https://<TOKEN>@github.com/pecorio-dev/NEO-Stream.git
   ```

### Avec SSH (Alternative)

```bash
# Configurer le remote SSH
git remote set-url origin git@github.com:pecorio-dev/NEO-Stream.git

# Push
git push -f origin main
```

---

## 🧹 Nettoyage post-push

Après le push réussi, vous pouvez supprimer ce fichier :

```bash
rm PUSH_TO_GITHUB.md
git add PUSH_TO_GITHUB.md
git commit -m "Remove push guide"
git push origin main
```

---

## ✅ Vérification

1. Visiter https://github.com/pecorio-dev/NEO-Stream
2. Vérifier que :
   - Le `README.md` s'affiche correctement
   - Tous les dossiers sont présents
   - Le code est à jour
   - Les commits sont visibles

---

## 🆘 Problèmes courants

### "failed to push some refs"
```bash
# Solution : Force push (attention !)
git push -f origin main
```

### "Authentication failed"
```bash
# Vérifier le token/credentials
git remote -v
git config --global credential.helper cache
```

### "Large files detected"
```bash
# Trouver les gros fichiers
find . -size +100M

# Les ajouter au .gitignore puis :
git rm --cached <fichier>
git commit -m "Remove large files"
```

### "Branch 'main' does not exist"
```bash
# Créer la branche main
git branch -M main
git push -u origin main
```

---

## 📚 Commandes utiles

```bash
# Voir l'historique
git log --oneline

# Voir les fichiers trackés
git ls-files

# Taille du repo
du -sh .git

# Annuler le dernier commit (local)
git reset --soft HEAD~1

# Voir les différences
git diff

# Voir l'état
git status
```

---

**🎯 Prêt à pusher !** Exécutez les commandes ci-dessus une par une.
