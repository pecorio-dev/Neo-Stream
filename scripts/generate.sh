#!/bin/bash

# Script de génération de code pour NEO STREAM
# Génère automatiquement tous les fichiers nécessaires

echo "🚀 NEO STREAM - Génération de code professionnel"
echo "================================================"

# Nettoie les anciens fichiers générés
echo "🧹 Nettoyage des anciens fichiers..."
flutter packages pub run build_runner clean

# Récupère les dépendances
echo "📦 Récupération des dépendances..."
flutter pub get

# Génère tous les fichiers
echo "⚡ Génération du code..."
flutter packages pub run build_runner build --delete-conflicting-outputs

# Vérifie que tout est OK
echo "✅ Vérification du code..."
flutter analyze

echo ""
echo "🎉 Génération terminée avec succès !"
echo "Vous pouvez maintenant lancer l'application avec: flutter run"