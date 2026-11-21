import { apiMe, apiProfiles, type AuthProfile } from "./api";
import { progressScope } from "./progress";
import { restoreProfile } from "./profiles";
import type { AccountProfile } from "./types";

type Recovery = {
  token: string;
  isCurrent: () => boolean;
  setBusy: (busy: boolean) => void;
  setError: (message: string) => void;
  acceptIdentity?: (profile: AuthProfile) => boolean;
  readSelected: (accountId: string, current: () => boolean) => Promise<string | null>;
  activate: (accountId: string, items: AccountProfile[], selected: AccountProfile) => void;
};

/** The authenticated scope is provisional until the directory confirms ownership. */
export function createProfileRefresh() {
  let pending: object | null = null;
  return {
    cancel() {
      const wasPending = pending !== null;
      pending = null;
      return wasPending;
    },
    async recover({ token, isCurrent, setBusy, setError, acceptIdentity, readSelected, activate }: Recovery) {
      if (pending || !isCurrent()) return;
      const attempt = {};
      pending = attempt;
      const current = () => pending === attempt && isCurrent();
      setBusy(true);
      setError("");
      let readingIdentity = true;
      try {
        const me = await apiMe(token);
        if (!current()) return;
        if (acceptIdentity && !acceptIdentity(me?.profile)) return;
        const scope = progressScope(me?.profile);
        if (!scope) {
          setError("Le serveur ne fournit pas encore l’identité nécessaire pour charger les profils.");
          return;
        }
        readingIdentity = false;
        const items = await apiProfiles(token, scope.accountId);
        if (!current()) return;
        const selectedId = await readSelected(scope.accountId, current);
        if (!current()) return;
        const selected = restoreProfile(items, selectedId);
        if (selected) activate(scope.accountId, items, selected);
      } catch (error) {
        if (current()) setError(readingIdentity ? "Impossible de vérifier la session auprès du serveur."
          : error instanceof Error ? error.message : "Profils indisponibles.");
      } finally {
        if (pending === attempt) {
          pending = null;
          if (isCurrent()) setBusy(false);
        }
      }
    },
  };
}
