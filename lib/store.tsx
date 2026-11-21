import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { Platform } from "react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as SecureStore from "expo-secure-store";
import { palettes, phonePalettes, tvPalettes } from "./theme";
import { activePreset, readPreferences } from './displayPresets';
import { portraitById } from './portraits';
import { createdPortraitUpdate, portraitScope, readPortraitChoices, type PortraitChoices } from './portraitChoice';
import {
  AccountProfile,
  AccountProfileChange,
  AuthenticatedAccount,
  Channel,
  Overlay,
  Preferences,
  Profile,
  Progress,
  SessionInfo,
  Theme,
  Title,
} from "./types";
import {
  API_BASE,
  apiCatalogueIds,
  apiGetProgress,
  apiLogin,
  apiLogout,
  apiPostProgress,
  apiProfiles,
  apiRegister,
  apiResend,
  apiRevokeSession,
  apiSessions,
  apiVerify,
  AuthResult,
  channelDirectoryFailure,
  hasService,
  loadCatalogue,
  loadChannels,
  SessionQuota,
  observeBearer,
} from "./api";
import { expiredSession, invalidSession, ownsContent, pendingLogin, provenSession, restoreAccess, serviceUnavailable, verifiedAccount, type AccessState } from './accessSession';
import { createLibraryStore, emptyLibrary, libraryKey, type Library, type LibraryAction } from './scopedLibrary';
import { progressScope, type ProgressIdentity } from "./progress";
import { createProgressSession } from "./progressSession";
import { restoreProfile, selectionKey } from "./profiles";
import { createProfileRefresh } from "./profileRefresh";
import { CATALOGUE_BATCH, historyCards, missingHistoryIds } from "./catalogueLookup";
import { createListRequests, createRefreshGate } from "./listRequests";
import { createReaderStartup } from './readerStartup';

type Saved = {
  portraits: PortraitChoices;
  prefs: Preferences;
  profile: Profile;
};
const initial: Saved = {
  portraits: {},
  profile: { name: "Profil", color: 0 },
  prefs: readPreferences(undefined, Platform.isTV),
};
const STORAGE = "neostream.cinema.v1";
let settingsWrite = Promise.resolve();
const accessLibrary = createLibraryStore(AsyncStorage);
const EMPTY_PROGRESS: Progress[] = [];
type NewProfilePortrait = { id: string | null; isCurrent: () => boolean };
interface State extends Saved, Library {
  account: AuthenticatedAccount | null;
  canChoosePortrait: boolean;
  choosePortrait: (id: string | null) => boolean;
  progress: Progress[];
  history: { entry: Progress; item: Title }[];
  ready: boolean;
  accessState: AccessState;
  accessError: string;
  canRetryAccess: boolean;
  retryAccess: () => void;
  phone: boolean;
  tv: boolean;
  theme: Theme;
  items: Title[];
  channels: Channel[];
  overlay: Overlay | null;
  canGoBack: boolean;
  toast: string;
  serviceError: string;
  channelDirectoryError: string;
  refreshing: boolean;
  token: string | null;
  authSessionId: number;
  readerStartup: ReturnType<typeof createReaderStartup>;
  authStep: "signed-out" | "pending" | "signed-in";
  pendingEmail: string;
  sessionInfo: SessionQuota | null;
  open: (s: Overlay) => void;
  back: () => void;
  dismiss: () => void;
  notify: (s: string) => void;
  toggleFavorite: (id: string) => void;
  addSearch: (s: string) => void;
  removeSearch: (s?: string) => void;
  setPreference: <K extends keyof Preferences>(
    key: K,
    value: Preferences[K],
  ) => void;
  profiles: AccountProfile[];
  profilesBusy: boolean;
  profilesError: string;
  reloadProfiles: () => Promise<void>;
  selectProfile: (id: string) => void;
  saveProfile: (change: AccountProfileChange, newPortrait?: NewProfilePortrait) => Promise<boolean>;
  saveProgress: (p: Progress) => void;
  clearProgress: (id?: string) => void;
  refresh: () => Promise<void>;
  loadMore: (what: "catalogue" | "channels") => Promise<void>;
  hasMoreCatalogue: boolean;
  hasMoreChannels: boolean;
  authenticate: (
    mode: "login" | "register",
    email: string,
    password: string,
    name?: string,
  ) => Promise<void>;
  register: (name: string, email: string, password: string) => Promise<void>;
  verifyCode: (email: string, code: string) => Promise<void>;
  resendCode: (email: string) => Promise<void>;
  loadSessions: () => Promise<SessionInfo[]>;
  revokeSession: (id: string) => Promise<void>;
  clearPending: () => void;
  logout: () => void;
}
const AppContext = createContext<State | null>(null);
export function useApp() {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error("AppProvider missing");
  return ctx;
}
const tokenStore = {
  get: () =>
    Platform.OS === "web"
      ? Promise.resolve(sessionStorage.getItem("neo.session"))
      : SecureStore.getItemAsync("neo.session"),
  set: (v: string) =>
    Platform.OS === "web"
      ? Promise.resolve(sessionStorage.setItem("neo.session", v))
      : SecureStore.setItemAsync("neo.session", v),
  remove: () =>
    Platform.OS === "web"
      ? Promise.resolve(sessionStorage.removeItem("neo.session"))
      : SecureStore.deleteItemAsync("neo.session"),
};
let tokenWrite = Promise.resolve();
const selectionWrites = new Map<string, Promise<void>>();
type ProfileAccount = { accountId: string; token: string; items: AccountProfile[]; busy: boolean };
function writeToken(token: string | null) {
  const task = tokenWrite.then(() => token ? tokenStore.set(token) : tokenStore.remove());
  tokenWrite = task.catch(() => {});
  return task;
}
const merge = <T extends { id: string }>(original: T[], incoming: T[]) =>
  Array.from(
    new Map([...original, ...incoming].map((v) => [v.id, v])).values(),
  );
function newSession(token: string | null, id: number) {
  return { token, id, readerStartup: createReaderStartup(), catalogueRequests: createListRequests(loadCatalogue),
    channelRequests: createListRequests(loadChannels), runRefresh: createRefreshGate() };
}
export function AppProvider({ children, phone, tv }: { children: React.ReactNode; phone: boolean; tv: boolean }) {
  const [saved, setSaved] = useState<Saved>(initial);
  const [ready, setReady] = useState(false);
  const [stack, setStack] = useState<Overlay[]>([]);
  const [toast, setToast] = useState("");
  const [items, setItems] = useState<Title[]>([]);
  const [channels, setChannels] = useState<Channel[]>([]);
  const [serviceError, setError] = useState("");
  const [channelIssue, setChannelIssue] = useState<ReturnType<typeof channelDirectoryFailure> | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [authSession, setAuthSession] = useState(() => newSession(null, 0));
  const [proof, setProof] = useState<{ session: typeof authSession; account: AuthenticatedAccount } | null>(null);
  const [checking, setChecking] = useState(true);
  const [accessError, setAccessError] = useState('');
  const [retryableFailure, setRetryableFailure] = useState(false);
  const checkingVersion = useRef<number | null>(null);
  const canRestore = useRef(true);
  // Preserve unowned v1 lists on disk without exposing them to any viewer.
  // null also blocks settings writes when their initial read failed.
  const legacyLists = useRef<{ favorites?: unknown; searches?: unknown } | null>(null);
  const detachObserver = useRef<(() => void) | null>(null);
  const { token } = authSession;
  const activeAuthSession = useRef(authSession);
  const confirmedOwnerId = useRef<string | undefined>(undefined);
  const commitToken = useCallback((next: string | null, account: AuthenticatedAccount | null = null) => {
    const previous = activeAuthSession.current;
    previous.readerStartup.close();
    const session = newSession(next, previous.id + 1);
    activeAuthSession.current = session;
    confirmedOwnerId.current = account?.accountId;
    setProof(account ? { session, account } : null);
    setAuthSession(session);
  }, []);
  const [progressIdentity, setProgressIdentity] = useState<ProgressIdentity | null>(null);
  const [libraryView, setLibraryView] = useState<{ owner: ProgressIdentity; data: Library } | null>(null);
  const [progressView, setProgressView] = useState<{ identity: ProgressIdentity; items: Progress[] } | null>(null);
  const [historyView, setHistoryView] = useState<{ identity: ProgressIdentity; items: Title[] } | null>(null);
  const [historyRetry, setHistoryRetry] = useState(0);
  const authVersion = useRef(0);
  const advanceAuthVersion = useCallback(() => ++authVersion.current, []);
  const activeToken = useRef<string | null>(null);
  const [profileAccount, setProfileAccount] = useState<ProfileAccount | null>(null);
  const activeProfileAccount = useRef<ProfileAccount | null>(null);
  const [profiles, setProfiles] = useState<AccountProfile[]>([]);
  const [profilesBusy, setProfilesBusy] = useState(false);
  const [profilesError, setProfilesError] = useState("");
  const [profileRefresh] = useState(createProfileRefresh);
  const mounted = useRef(false);
  const activeProgressIdentity = useRef<ProgressIdentity | null>(null);
  const progressSession = useRef<ReturnType<typeof createProgressSession> | null>(null);
  const [authStep, setAuthStep] = useState<
    "signed-out" | "pending" | "signed-in"
  >("signed-out");
  const [pendingEmail, setPendingEmail] = useState("");
  const [sessionInfo, setSessionInfo] = useState<SessionQuota | null>(null);
  const [cursors, setCursors] = useState<{
    catalogue: string | null;
    channels: string | null;
  }>({ catalogue: null, channels: null });
  const { catalogueRequests, channelRequests, runRefresh } = authSession;
  const onChannelFailure = useCallback((error: unknown) => {
    const issue = channelDirectoryFailure(error);
    if (issue.status === 403) {
      channelRequests.stopPagination();
      setCursors((v) => ({ ...v, channels: null }));
    }
    setChannelIssue(issue);
  }, [channelRequests]);
  const toastTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const notify = useCallback((s: string) => {
    if (toastTimer.current) clearTimeout(toastTimer.current);
    setToast(s);
    toastTimer.current = setTimeout(() => setToast(""), 2600);
  }, []);
  const beginAuthChange = useCallback(() => {
    if (profileRefresh.cancel()) setProfilesBusy(false);
    checkingVersion.current = null;
    canRestore.current = false;
    setRetryableFailure(false);
    setChecking(false);
    setAccessError('');
    return advanceAuthVersion();
  }, [advanceAuthVersion, profileRefresh]);
  const replaceProgress = useCallback((identity: ProgressIdentity | null, preserveNavigation = false) => {
    progressSession.current?.stop();
    progressSession.current = null;
    activeProgressIdentity.current = identity;
    setLibraryView(null);
    setProgressIdentity(identity);
    setProgressView(null);
    setHistoryView(null);
    if (!preserveNavigation) setStack((overlays) => overlays.filter((s) => s.type !== "watch"));
  }, []);
  const activateProfile = useCallback((account: ProfileAccount, profile: AccountProfile, preserveNavigation = false) => {
    if (activeProfileAccount.current !== account) return;
    const current = activeProgressIdentity.current;
    if (current?.profileId !== profile.id || current.accountId !== account.accountId || current.token !== account.token)
      replaceProgress({ accountId: account.accountId, profileId: profile.id, token: account.token }, preserveNavigation);
    setSaved((v) => ({ ...v, profile: { ...v.profile, accountId: account.accountId, profileId: profile.id, name: profile.name, color: profile.color } }));
  }, [replaceProgress]);
  const syncProfiles = useCallback(async (account: ProfileAccount, change?: AccountProfileChange, newPortrait?: NewProfilePortrait): Promise<boolean> => {
    const isCurrent = () => activeProfileAccount.current === account;
    if (!isCurrent() || account.busy) return false;
    const version = authVersion.current;
    const draft = change?.action === "create" && newPortrait
      && (newPortrait.id === null || portraitById.has(newPortrait.id)) ? newPortrait : undefined;
    const before = draft ? account.items.map(item => item.id) : [];
    account.busy = true;
    setProfilesBusy(true);
    setProfilesError("");
    try {
      const profiles = await apiProfiles(account.token, account.accountId, change);
      if (!isCurrent()) return false;
      const key = selectionKey(API_BASE, account.accountId);
      const currentId = activeProgressIdentity.current?.profileId;
      if (!currentId) await selectionWrites.get(key)?.catch(() => {});
      if (!isCurrent()) return false;
      const selectedId = currentId ?? await AsyncStorage.getItem(key).catch(() => null);
      if (!isCurrent()) return false;
      const selected = restoreProfile(profiles, selectedId);
      account.items = profiles;
      setProfiles(profiles);
      if (selected) activateProfile(account, selected);
      if (draft) {
        // The POST still sends only `change`; this choice belongs to local settings.
        const canCommit = () => isCurrent() && version === authVersion.current
          && account.token === activeToken.current && draft.isCurrent();
        if (canCommit()) {
          const update = createdPortraitUpdate<Saved>(
            API_BASE, account.accountId, before, profiles.map(item => item.id), draft.id, canCommit,
          );
          if (update) setSaved(update);
        }
      }
      return true;
    } catch (error) {
      if (!isCurrent()) return false;
      if (change) throw error;
      setProfilesError(error instanceof Error ? error.message : "Profils indisponibles.");
      return false;
    } finally {
      account.busy = false;
      if (isCurrent()) setProfilesBusy(false);
    }
  }, [activateProfile]);
  const resetContent = useCallback((granted: boolean) => {
    /* eslint-disable @typescript-eslint/no-require-imports -- defer bundled media modules until server confirmation */
    setItems(granted ? (require('./catalogue') as typeof import('./catalogue')).catalogue : []);
    setChannels(granted ? (require('./channelDirectory') as typeof import('./channelDirectory')).initialLiveChannels(API_BASE) : []);
    /* eslint-enable @typescript-eslint/no-require-imports */
    setCursors({ catalogue: null, channels: null });
    setStack([]);
    setToast('');
    setRefreshing(false);
    setChannelIssue(null);
    setError('');
  }, []);
  const lock = useCallback((message: string) => {
    beginAuthChange();
    detachObserver.current?.();
    detachObserver.current = null;
    activeToken.current = null;
    activeProfileAccount.current = null;
    setProfileAccount(null);
    setProfiles([]);
    setProfilesBusy(false);
    setProfilesError('');
    replaceProgress(null);
    resetContent(false);
    commitToken(null);
    setSessionInfo(null);
    setPendingEmail('');
    setAuthStep('signed-out');
    setAccessError(message);
    setSaved(v => ({ ...v, profile: initial.profile }));
    void writeToken(null).catch(() => {});
  }, [beginAuthChange, commitToken, replaceProgress, resetContent]);
  const applySignIn = useCallback((result: AuthResult) => {
    profileRefresh.cancel();
    replaceProgress(null);
    const scope = progressScope(result.profile);
    activeToken.current = result.token;
    detachObserver.current?.();
    detachObserver.current = observeBearer(result.token, () => lock(expiredSession));
    const account = scope ? { accountId: scope.accountId, token: result.token, items: [], busy: false } : null;
    activeProfileAccount.current = account;
    setProfileAccount(account);
    setProfiles([]);
    setProfilesBusy(false);
    setProfilesError(account ? "" : "Les profils ne sont pas disponibles sur ce serveur.");
    resetContent(true);
    commitToken(result.token, verifiedAccount(result.profile));
    setPendingEmail("");
    setSessionInfo(result.sessions || null);
    setAuthStep("signed-in");
    setAccessError('');
    setChecking(false);
    setSaved((v) => ({
      ...v,
      profile: { ...initial.profile, connected: true },
    }));
    if (account) void syncProfiles(account);
  }, [commitToken, lock, profileRefresh, replaceProgress, resetContent, syncProfiles]);
  const retryAccess = useCallback(() => {
    if (!mounted.current || !canRestore.current || activeToken.current || checkingVersion.current !== null) return;
    const version = advanceAuthVersion();
    checkingVersion.current = version;
    setChecking(true);
    setAccessError('');
    const current = () => mounted.current && version === authVersion.current;
    void restoreAccess(() => tokenWrite.then(() => tokenStore.get()), current).then(outcome => {
      if (!outcome || !current()) return;
      checkingVersion.current = null;
      canRestore.current = outcome.state === 'locked' && !!outcome.error && !outcome.discard;
      setRetryableFailure(canRestore.current);
      if (outcome.state === 'granted') applySignIn(outcome.result);
      else {
        if (outcome.discard) void writeToken(null).catch(() => {});
        setChecking(false);
        setAccessError(outcome.error);
      }
    });
  }, [advanceAuthVersion, applySignIn]);
  useEffect(() => {
    mounted.current = true;
    let alive = true;
    canRestore.current = true;
    retryAccess();
    (async () => {
      try {
        await settingsWrite;
        const raw = await AsyncStorage.getItem(STORAGE);
        if (!alive) return;
        if (raw) {
          try {
            const d = JSON.parse(raw);
            if (!d || typeof d !== 'object' || Array.isArray(d)) return;
            legacyLists.current = { favorites: d.favorites, searches: d.searches };
            setSaved(v => ({
              ...v,
              prefs: readPreferences(d.prefs, Platform.isTV),
              portraits: readPortraitChoices(d.portraits, id => portraitById.has(id)),
            }));
          } catch { /* Ignore malformed legacy settings, not the bearer. */ }
        } else if (raw === null) legacyLists.current = {};
      } catch {
        /* Storage can be unavailable in private browsing. A usable in-memory session remains. */
      } finally {
        if (alive) setReady(true);
      }
    })();
    return () => {
      alive = false;
      mounted.current = false;
      advanceAuthVersion();
      checkingVersion.current = null;
      detachObserver.current?.();
      profileRefresh.cancel();
      activeProfileAccount.current = null;
      if (toastTimer.current) clearTimeout(toastTimer.current);
    };
  }, [advanceAuthVersion, retryAccess, profileRefresh]);
  useEffect(() => {
    if (!progressIdentity || progressIdentity !== activeProgressIdentity.current) return;
    const session = createProgressSession(progressIdentity, {
      service: API_BASE,
      read: (key) => AsyncStorage.getItem(key),
      write: (key, value) => AsyncStorage.setItem(key, value),
      get: apiGetProgress,
      post: apiPostProgress,
      show: (items) => setProgressView({ identity: progressIdentity, items }),
      storageError: () => notify("Stockage indisponible : progression conservée pour cette session."),
    });
    progressSession.current = session;
    void session.start();
    return () => {
      session.stop();
      if (progressSession.current === session) progressSession.current = null;
    };
  }, [progressIdentity, notify]);
  const progress = progressView && progressView.identity === progressIdentity ? progressView.items : EMPTY_PROGRESS;
  const syncLibrary = useCallback((action?: LibraryAction) => {
    const current = () => ownsContent(authSession, activeAuthSession.current, mounted.current)
      && progressIdentity === activeProgressIdentity.current;
    if (!current()) return;
    if (!progressIdentity) {
      if (action && 'toggle' in action) notify('Un profil confirmé est nécessaire pour enregistrer un favori.');
      return;
    }
    void accessLibrary(libraryKey(API_BASE, progressIdentity), current, action).then(data => {
      if (!data || !current()) return;
      setLibraryView({ owner: progressIdentity, data });
      if (action && 'toggle' in action) notify(data.favorites.includes(action.toggle)
        ? 'Titre ajouté à votre liste' : 'Titre retiré de votre liste');
    }).catch(() => {
      if (current()) notify('Bibliothèque indisponible : aucune modification enregistrée.');
    });
  }, [authSession, progressIdentity, notify]);
  useEffect(() => { syncLibrary(); }, [syncLibrary]);
  const missingHistory = useMemo(() => missingHistoryIds(progress, items).join(","), [progress, items]);
  const history = useMemo(() => historyCards(progressIdentity, progress, items, historyView), [progressIdentity, progress, items, historyView]);
  useEffect(() => {
    if (!hasService || !progressIdentity || !missingHistory || progressIdentity !== activeProgressIdentity.current) return;
    let active = true;
    const ids = missingHistory.split(",");
    const current = () => active && progressIdentity === activeProgressIdentity.current;
    void (async () => {
      for (let i = 0; i < ids.length && current(); i += CATALOGUE_BATCH) {
        try {
          const resolved = await apiCatalogueIds(ids.slice(i, i + CATALOGUE_BATCH));
          if (!current()) return;
          setHistoryView((previous) => current() ? {
            identity: progressIdentity,
            items: merge(previous?.identity === progressIdentity ? previous.items : [], resolved),
          } : previous);
        } catch {
          // Keep progress untouched and retry metadata on the next explicit refresh.
          return;
        }
      }
    })();
    return () => { active = false; };
  }, [progressIdentity, missingHistory, historyRetry]);
  useEffect(() => {
    if (ready && legacyLists.current) {
      const settings = { ...legacyLists.current, prefs: saved.prefs, portraits: saved.portraits };
      settingsWrite = settingsWrite.then(() => AsyncStorage.setItem(STORAGE, JSON.stringify(settings))).catch(() =>
        notify(
          "Stockage indisponible : modifications conservées pour cette session.",
        ),
      );
    }
  }, [saved.prefs, saved.portraits, ready, notify]);
  const refresh = useCallback((retryProgress = true) => runRefresh(async () => {
    const current = () => ownsContent(authSession, activeAuthSession.current, mounted.current);
    if (!current()) return;
    if (retryProgress) {
      void progressSession.current?.retry();
      setHistoryRetry((value) => value + 1);
    }
    setRefreshing(true);
    setError("");
    try {
        const [titles] = await Promise.allSettled([
          catalogueRequests.refresh((page) => {
            if (!current()) return;
            setItems((v) => merge(v, page.items));
            setCursors((v) => ({ ...v, catalogue: page.nextCursor }));
          }),
          channelRequests.refresh((page) => {
            if (!current()) return;
            setChannels(page.items);
            setCursors((v) => ({ ...v, channels: page.nextCursor }));
            setChannelIssue(null);
          }).catch(error => { if (current()) onChannelFailure(error); }),
        ]);
        if (current() && (titles.status === 'rejected' || titles.value === 'skipped')) setError('Le catalogue n’a pas pu être actualisé. Le catalogue déjà chargé reste accessible.');
    } catch {
      if (current()) setError(
        "Le service ne répond pas. Votre sélection enregistrée reste disponible.",
      );
    } finally {
      if (current()) setRefreshing(false);
    }
  }), [authSession, catalogueRequests, channelRequests, onChannelFailure, runRefresh]);
  useEffect(() => {
    if (!token) return;
    // Render the bundled collection first, then reconcile with the remote service.
    const job = requestAnimationFrame(() => {
      void refresh(false);
    });
    return () => cancelAnimationFrame(job);
  }, [refresh, token]);
  const loadMore = async (what: "catalogue" | "channels") => {
    const current = () => ownsContent(authSession, activeAuthSession.current, mounted.current);
    if (!current()) return;
    const onError = () => { if (current()) notify("Chargement interrompu. Faites défiler pour réessayer."); };
    if (what === "catalogue") {
      await catalogueRequests.loadMore((page) => {
        if (!current()) return;
        setItems((v) => merge(v, page.items));
        setCursors((v) => ({ ...v, catalogue: page.nextCursor }));
      }, onError);
    } else {
      await channelRequests.loadMore((page) => {
        if (!current()) return;
        setChannels((v) => merge(v, page.items));
        setCursors((v) => ({ ...v, channels: page.nextCursor }));
        setChannelIssue(null);
      }, error => { if (current()) onChannelFailure(error); });
    }
  };
  const finishSignIn = useCallback(async (result: AuthResult, version: number) => {
    if (version !== authVersion.current) {
      // The request could have created a server session after logout.
      if (provenSession(result) && result.token !== activeToken.current) void apiLogout(result.token).catch(() => {});
      return false;
    }
    if (!provenSession(result)) throw new Error(invalidSession);
    applySignIn(result);
    await writeToken(result.token).catch(() => {
      if (version === authVersion.current) notify("Session utilisable mais non enregistrée sur cet appareil.");
    });
    return version === authVersion.current;
  }, [applySignIn, notify]);
  const register = useCallback(
    async (name: string, email: string, password: string) => {
      if (!hasService)
        throw new Error("Le service Neo-stream n’est pas configuré.");
      const version = beginAuthChange();
      const result = await apiRegister(name.trim(), email.trim(), password);
      if (version !== authVersion.current) return;
      if (result?.pending !== true) throw new Error('Réponse d’inscription non valide.');
      setPendingEmail(result.email || email.trim());
      setAuthStep("pending");
      notify(
        result.emailSent === false
          ? "L’e-mail n’a pas pu être envoyé. Utilisez « Renvoyer le code »."
          : "Un code de vérification vous a été envoyé par e-mail.",
      );
    },
    [beginAuthChange, notify],
  );
  const verifyCode = useCallback(
    async (email: string, code: string) => {
      const version = beginAuthChange();
      const result = await apiVerify(email.trim(), code.trim());
      if (await finishSignIn(result, version))
        notify("Adresse vérifiée. Vous êtes connecté à Neo-stream.");
    },
    [beginAuthChange, finishSignIn, notify],
  );
  const resendCode = useCallback(
    async (email: string) => {
      const version = authVersion.current;
      const result = await apiResend(email.trim());
      if (version !== authVersion.current) return;
      setPendingEmail(email.trim());
      notify(result.sent
        ? "Si votre adresse est en attente de vérification, consultez vos e-mails."
        : "Aucun nouveau code n’a été envoyé. Réessayez dans un instant.");
    },
    [notify],
  );
  const loadSessions = useCallback(async (): Promise<SessionInfo[]> => {
    if (!token || authSession !== activeAuthSession.current) return [];
    const data = await apiSessions(token);
    if (authSession !== activeAuthSession.current) return [];
    const items = Array.isArray(data.items) ? data.items : [];
    const safe = items.filter(
      (s): s is SessionInfo => !!s && typeof s.id === "string" && !!s.id,
    );
    setSessionInfo({
      active: safe.length,
      limit: typeof data.limit === "number" ? data.limit : 4,
    });
    return safe;
  }, [authSession, token]);
  const revokeSession = useCallback(
    async (id: string) => {
      if (!token || authSession !== activeAuthSession.current) throw new Error("Session expirée. Reconnectez-vous.");
      await apiRevokeSession(token, id);
      if (authSession !== activeAuthSession.current) return;
      setSessionInfo((v) =>
        v ? { ...v, active: Math.max(0, v.active - 1) } : v,
      );
      notify("Appareil déconnecté.");
    },
    [authSession, notify, token],
  );
  const clearPending = useCallback(() => {
    beginAuthChange();
    setAuthStep("signed-out");
    setPendingEmail("");
  }, [beginAuthChange]);
  const authenticate = useCallback(
    async (
      mode: "login" | "register",
      email: string,
      password: string,
      name?: string,
    ) => {
      if (mode === "register") return register(name || "", email, password);
      const version = beginAuthChange();
      const result = await apiLogin(email.trim(), password).catch(error => {
        const pending = pendingLogin(error, email);
        if (version === authVersion.current && !activeToken.current && pending) {
          setPendingEmail(pending.pendingEmail);
          setAuthStep(pending.authStep);
        }
        throw error;
      });
      if (await finishSignIn(result, version)) notify("Vous êtes connecté à Neo-stream.");
    },
    [beginAuthChange, finishSignIn, notify, register],
  );
  const appearance = activePreset(saved.prefs.display).base;
  const reloadProfiles = useCallback(async () => {
    if (!mounted.current || authStep !== "signed-in" || !token || authSession !== activeAuthSession.current) return;
    const account = activeProfileAccount.current;
    if (account) {
      await syncProfiles(account);
      return;
    }
    const version = authVersion.current;
    await profileRefresh.recover({
      token,
      isCurrent: () => mounted.current && version === authVersion.current && authSession === activeAuthSession.current,
      acceptIdentity: profile => {
        const account = verifiedAccount(profile);
        const owner = confirmedOwnerId.current;
        if (!account || (owner && account.accountId && account.accountId !== owner)) {
          lock(invalidSession);
          return false;
        }
        // Updating display data must not retrigger the sheet's on-open /me request.
        // Only the actual /me response and profile directory can open a library.
        confirmedOwnerId.current = account.accountId ?? owner;
        setProof({ session: authSession, account: owner && !account.accountId ? { ...account, accountId: owner } : account });
        return true;
      },
      setBusy: setProfilesBusy,
      setError: setProfilesError,
      readSelected: async (accountId, current) => {
        const key = selectionKey(API_BASE, accountId);
        await selectionWrites.get(key)?.catch(() => {});
        return current() ? AsyncStorage.getItem(key).catch(() => null) : null;
      },
      activate: (accountId, items, selected) => {
        const recovered = { accountId, token, items, busy: false };
        activeProfileAccount.current = recovered;
        setProfileAccount(recovered);
        setProfiles(items);
        activateProfile(recovered, selected, true);
      },
    });
  }, [activateProfile, authSession, authStep, lock, profileRefresh, syncProfiles, token]);
  const overlay = stack.at(-1) || null;
  const portraitKey = progressIdentity ? portraitScope(API_BASE, saved.profile) : null;
  const value: State = {
    ...saved,
    account: proof?.session === authSession ? proof.account : null,
    ...(libraryView && libraryView.owner === progressIdentity ? libraryView.data : emptyLibrary),
    profile: { ...saved.profile, portraitId: portraitKey ? saved.portraits[portraitKey] : undefined },
    canChoosePortrait: ready && !!portraitKey,
    choosePortrait: (id) => {
      if (!ready || !portraitKey || authSession !== activeAuthSession.current || progressIdentity !== activeProgressIdentity.current
        || (id !== null && !portraitById.has(id))) return false;
      setSaved(v => {
        if (portraitScope(API_BASE, v.profile) !== portraitKey) return v;
        const portraits = { ...v.portraits };
        if (id === null) delete portraits[portraitKey]; else portraits[portraitKey] = id;
        return { ...v, portraits };
      });
      return true;
    },
    progress,
    history,
    ready: ready && !checking,
    accessState: token ? 'granted' : checking ? 'checking' : 'locked',
    accessError: hasService ? accessError : serviceUnavailable,
    canRetryAccess: hasService && !token && !checking && !!accessError && retryableFailure,
    retryAccess,
    phone,
    tv,
    theme: (tv ? tvPalettes : phone ? phonePalettes : palettes)[appearance],
    items,
    channels,
    token,
    authSessionId: authSession.id,
    readerStartup: authSession.readerStartup,
    authStep,
    pendingEmail,
    sessionInfo,
    overlay,
    canGoBack: stack.length > 1,
    toast,
    serviceError,
    channelDirectoryError: hasService ? channelIssue?.message ?? '' : 'Aucun service de direct n’est configuré. Seules les chaînes intégrées peuvent être ouvertes.',
    refreshing,
    hasMoreCatalogue: !!cursors.catalogue,
    hasMoreChannels: !!cursors.channels,
    refresh: () => refresh(),
    loadMore,
    authenticate,
    register,
    verifyCode,
    resendCode,
    loadSessions,
    revokeSession,
    clearPending,
    open: (s) => { if (token && authSession === activeAuthSession.current) setStack((v) => [...v, s.type === "watch" ? { ...s } : s]); },
    back: () => setStack((v) => v.slice(0, -1)),
    dismiss: () => setStack([]),
    notify,
    toggleFavorite: (id) => syncLibrary({ toggle: id }),
    addSearch: (s) => {
      const q = s.trim();
      if (q && saved.prefs.rememberSearch) syncLibrary({ search: q });
    },
    removeSearch: (s) => syncLibrary({ remove: s }),
    setPreference: (key, val) =>
      setSaved((v) => ({ ...v, prefs: { ...v.prefs, [key]: val } })),
    profiles,
    profilesBusy,
    profilesError,
    reloadProfiles,
    selectProfile: (id) => {
      if (!profileAccount || activeProfileAccount.current !== profileAccount || profileAccount.busy) return;
      const selected = profileAccount.items.find((p) => p.id === id);
      if (!selected) return;
      activateProfile(profileAccount, selected);
      const key = selectionKey(API_BASE, profileAccount.accountId);
      const task = (selectionWrites.get(key) ?? Promise.resolve()).catch(() => {})
        .then(() => AsyncStorage.setItem(key, id));
      selectionWrites.set(key, task);
      void task.catch(() => {
        if (activeProfileAccount.current === profileAccount && activeProgressIdentity.current?.profileId === id)
          notify("Le profil est actif mais la sélection n’a pas pu être enregistrée.");
      }).finally(() => {
        if (selectionWrites.get(key) === task) selectionWrites.delete(key);
      });
    },
    saveProfile: (change, newPortrait) => profileAccount ? syncProfiles(profileAccount, change, newPortrait) : Promise.resolve(false),
    saveProgress: (p) => {
      if (saved.prefs.history && progressIdentity === activeProgressIdentity.current)
        progressSession.current?.save(p, overlay?.type === "watch" ? overlay : undefined);
    },
    clearProgress: (id) => {
      if (progressIdentity === activeProgressIdentity.current) progressSession.current?.clear(id);
    },
    logout: () => {
      if (authSession !== activeAuthSession.current) return;
      const current = activeToken.current;
      lock('');
      if (current && hasService) void apiLogout(current).catch(() => {});
      notify("Vous êtes déconnecté.");
    },
  };
  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}
