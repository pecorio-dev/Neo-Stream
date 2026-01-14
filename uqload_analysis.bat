@echo off
echo Analyse du fonctionnement d'Uqload - Headers et Connexion
echo =========================================================

echo.
echo 1. Test de connexion basique sans headers:
curl -I -s --insecure "https://uqload.bz" | findstr "HTTP Set-Cookie Content-Type Server"

echo.
echo 2. Test avec headers User-Agent Android:
curl -I -s --insecure -H "User-Agent: Mozilla/5.0 (Linux; Android 10; SM-A105F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36" "https://uqload.bz" | findstr "HTTP Set-Cookie Content-Type Server"

echo.
echo 3. Test avec headers complets comme dans notre application:
curl -I -s --insecure ^
-H "User-Agent: Mozilla/5.0 (Linux; Android 10; SM-A105F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36" ^
-H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" ^
-H "Accept-Language: fr-FR,fr;q=0.9,en;q=0.8" ^
-H "Accept-Encoding: identity" ^
-H "Connection: keep-alive" ^
-H "Upgrade-Insecure-Requests: 1" ^
-H "Sec-Fetch-Dest: document" ^
-H "Sec-Fetch-Mode: navigate" ^
-H "Sec-Fetch-Site: none" ^
"https://uqload.bz" | findstr "HTTP Set-Cookie Content-Type Server"

echo.
echo 4. Test de connexion à un domaine IP (simulé) - pour comprendre les erreurs SSL:
echo Remarque: Les erreurs SSL surviennent quand on accède à une IP avec un certificat pour un domaine
echo La configuration Android network_security_config permet de contourner ces erreurs

echo.
echo 5. Test de récupération d'une page d'embed (sans URL réelle pour des raisons de respect des CGU):
echo Pour tester avec une vraie URL, on utiliserait:
echo curl -s --insecure -H "User-Agent:..." "https://uqload.bz/embed-XXXXXXXXX.html"

echo.
echo Headers essentiels pour Uqload:
echo - User-Agent mobile Android (important pour éviter le blocage)
echo - Accept-Encoding: identity (éviter les problèmes de compression)
echo - Sec-Fetch-Mode: navigate ou no-cors (gestion des requêtes cross-origin)
echo - Range: bytes=0- (pour la lecture progressive des vidéos)
echo - Referer: l'URL d'origine (obligatoire pour la plupart des services d'hébergement vidéos)

echo.
echo Conclusion:
echo Notre configuration Android et Flutter utilise ces headers pour:
echo 1. Contourner les restrictions User-Agent
echo 2. Gérer correctement les requêtes cross-origin
echo 3. Permettre la lecture de vidéos hébergées sur des domaines/IPS différents
echo 4. Gérer les erreurs SSL liées aux certificats wildcard sur IPs

pause