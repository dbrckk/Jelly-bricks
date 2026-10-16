/** Lightweight install and offline helpers, with no dependencies or telemetry. */
export function connectionMessage(online) {
  return online ? "Connexion détectée" : "Hors connexion · jeu disponible hors ligne";
}
export function installMessage(standalone = false) {
  return standalone ? "Application installée" : "Installer le jeu";
}
export function manualInstallInstructions(platform = "android") {
  if (platform === "ios") {
    return "Dans Safari, ouvre Partager, puis « Sur l’écran d’accueil ».";
  }
  return "Dans le navigateur Android, ouvre le menu ⋮, puis choisis « Installer l’application » ou « Ajouter à l’écran d’accueil ».";
}
export function isStandalone(displayModeMatches, iosStandalone = false) {
  return Boolean(displayModeMatches || iosStandalone);
}
