import { Linking, Platform } from "react-native";
import { safeUrl } from "./api";
import { validateLegalUrl } from "./legal";
export async function openLink(url: string, notify: (message: string) => void) {
  if (!safeUrl(url)) {
    notify("Ce lien n’est pas disponible.");
    return;
  }
  try {
    if (Platform.OS === "web")
      window.open(url, "_blank", "noopener,noreferrer");
    else await Linking.openURL(url);
  } catch {
    notify("Impossible d’ouvrir le lien. Vérifiez votre connexion.");
  }
}

// A separate entry point: legal pages do not use the general-purpose link policy.
export async function openOfficialLegalLink(value: string): Promise<void> {
  const url = validateLegalUrl(value);
  if (!url) throw new Error("Invalid official legal URL");
  if (Platform.OS === "web") {
    window.open(url, "_blank", "noopener,noreferrer");
  } else {
    await Linking.openURL(url);
  }
}
