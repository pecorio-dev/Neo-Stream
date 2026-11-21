import { ApiHttpError, apiMe, hasService, shouldDiscardStoredBearer, verifiedProfile, type AuthProfile, type AuthResult } from './api';
import type { AuthenticatedAccount } from './types';

export type AccessState = 'checking' | 'locked' | 'granted';
export const serviceUnavailable = 'Le service Neo-stream n’est pas configuré.';
export const invalidSession = 'Session non valide ou adresse e-mail non vérifiée. Reconnectez-vous.';
export const expiredSession = 'Votre session a expiré. Reconnectez-vous.';
export function pendingLogin(error: unknown, email: string) {
  return error instanceof ApiHttpError && error.status === 403 && error.code === 'EMAIL_NOT_VERIFIED'
    ? { authStep: 'pending' as const, pendingEmail: email.trim() } : null;
}
export function ownsContent(session: { token: string | null }, current: object, mounted: boolean) {
  return mounted && !!session.token && session === current;
}
export function provenSession(result: AuthResult | null | undefined): result is AuthResult {
  return !!result && typeof result.token === 'string' && /^\S+$/.test(result.token) && verifiedProfile(result.profile);
}

export function verifiedAccount(profile: AuthProfile): AuthenticatedAccount | null {
  if (!verifiedProfile(profile)) return null;
  return { name: (typeof profile.name === 'string' && profile.name.trim()) || profile.email,
    email: profile.email, emailVerified: true,
    ...(typeof profile.accountId === 'string' && /^[1-9][0-9]{0,19}(?![\s\S])/.test(profile.accountId) ? { accountId: profile.accountId } : {}) };
}

type Restoration = { state: 'granted'; result: AuthResult } | { state: 'locked'; error: string; discard?: true };
/** Pure decision about this attempt; caller must still own the attempt to publish or delete anything. */
export async function restoreAccess(read: () => Promise<string | null>, current: () => boolean): Promise<Restoration | undefined> {
  if (!hasService) return { state: 'locked', error: serviceUnavailable };
  let token: string | null;
  try { token = await read(); } catch {
    return current() ? { state: 'locked', error: 'Impossible de lire la session enregistrée. Réessayez ou reconnectez-vous.' } : undefined;
  }
  try {
    if (!current()) return;
    if (!token) return { state: 'locked', error: '' };
    if (typeof token !== 'string' || !/^\S+$/.test(token)) return { state: 'locked', error: invalidSession, discard: true };
    const result = { ...await apiMe(token), token };
    if (!current()) return;
    return provenSession(result) ? { state: 'granted', result } : { state: 'locked', error: invalidSession, discard: true };
  } catch (error) {
    if (!current()) return;
    return shouldDiscardStoredBearer(error) ? { state: 'locked', error: expiredSession, discard: true }
      : { state: 'locked', error: 'Impossible de vérifier votre session. Vérifiez votre connexion puis réessayez.' };
  }
}
