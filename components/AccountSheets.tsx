import React, { useEffect, useLayoutEffect, useRef, useState } from "react";
import { Image, Switch, Text, View } from "react-native";
import { SheetInput, type Editor } from './SheetInput';
import { SheetText as T } from './SheetText';
import { useApp } from "../lib/store";
import { fonts } from "../lib/theme";
import { hasService, OFFICIAL_SITE } from "../lib/api";
import { SessionInfo } from "../lib/types";
import { DisplayPresets } from './DisplayPresets';
import { PortraitChooser } from './PortraitChooser';
import { openLink, openOfficialLegalLink } from "../lib/links";
import { validateLegalUrl } from "../lib/legal";
import { Avatar, avatarColors } from "./Brand";
import { Glass, GlassLayer } from './Glass';
import {
  Art,
  Button,
  Chip,
  Click,
  Empty,
  IconButton,
  IconName,
  I,
  row,
  useLayout,
  useTvInputFocus,
} from "./UI";
import { explore } from "../lib/navigation";
import { isEpisodicTitle } from "../lib/resume";
function SheetHeading({
  title,
  description,
}: {
  title: string;
  description?: string;
}) {
  const { theme, tv, profile } = useApp();
  const { phone } = useLayout();
  const personal = phone && title === 'Mon profil' && !!profile.profileId;
  return (
    <View style={[phone ? { gap: 5, marginBottom: 16, paddingBottom: 12, borderBottomWidth: 1, borderColor: theme.border } : { gap: 8, marginBottom: 22, paddingRight: 38 }, personal && { padding: 16, backgroundColor: theme.surface, borderRadius: 8, borderBottomWidth: 0 }]}>
      {personal && <View style={[row, { gap: 9, marginBottom: 10 }]}><Avatar size={40} index={profile.color} portraitId={profile.portraitId} /><T color={theme.accent} weight="bold">{profile.name}</T></View>}
      <T role="header" size={phone ? 32 : 39} weight="display" style={{ letterSpacing: -.5 }}>
        {title}
      </T>
      {description && (
        <T size={tv ? 20 : 13} color={theme.muted} style={{ lineHeight: tv ? 29 : 21 }}>
          {description}
        </T>
      )}
    </View>
  );
}
function MenuRow({
  title,
  sub,
  subSize = 12,
  icon,
  onPress,
  preferred = false,
}: {
  title: string;
  sub?: string;
  subSize?: number;
  icon: IconName;
  onPress: () => void;
  preferred?: boolean;
}) {
  const { theme, tv } = useApp();
  return (
    <Click
      label={tv ? [title, sub].filter(Boolean).join(', ') : undefined}
      autoFocus={tv && preferred}
      onPress={onPress}
      style={[
        row,
        {
          gap: 12,
          paddingVertical: 13,
          borderTopWidth: 1,
          borderColor: theme.border,
        },
      ]}
    >
      <View
        style={{ padding: 9, borderRadius: 12, overflow: 'hidden', borderColor: theme.glassEdge, borderWidth: 1 }}
      >
        <GlassLayer />
        <I name={icon} size={17} color={theme.muted} />
      </View>
      <View style={{ flex: 1, gap: 3 }}>
        <T size={14} weight="bold">
          {title}
        </T>
        {sub && (
          <T size={subSize} color={theme.muted}>
            {sub}
          </T>
        )}
      </View>
      <I name="chevron-forward" size={15} color={theme.faint} />
    </Click>
  );
}
function ToggleRow({
  title,
  description,
  value,
  onChange,
}: {
  title: string;
  description: string;
  value: boolean;
  onChange: (v: boolean) => void;
}) {
  const { theme } = useApp();
  const { focusProps, focusStyle } = useTvInputFocus();
  return (
    <View
      style={[
        row,
        {
          gap: 17,
          justifyContent: "space-between",
          paddingVertical: 13,
          borderBottomWidth: 1,
          borderColor: theme.border,
        },
      ]}
    >
      <View style={{ flex: 1, gap: 4 }}>
        <T size={13} weight="semibold">
          {title}
        </T>
        <T size={12} color={theme.muted} style={{ lineHeight: 18 }}>
          {description}
        </T>
      </View>
      <Switch
        {...focusProps}
        style={focusStyle}
        accessibilityLabel={title}
        value={value}
        onValueChange={onChange}
        {...{ activeThumbColor: theme.onAccent }}
        thumbColor={value ? theme.onAccent : theme.faint}
        trackColor={{ true: theme.accent, false: theme.elevated }}
      />
    </View>
  );
}
function MiniTitle({ text, icon }: { text: string; icon: IconName }) {
  const { theme } = useApp();
  return (
    <View style={[row, { gap: 8, marginBottom: 8 }]}>
      <I name={icon} size={17} color={theme.accent} />
      <T size={24} weight="display" role="header" style={{ letterSpacing: -0.2 }}>
        {text}
      </T>
    </View>
  );
}
function Wrap({ children }: { children: React.ReactNode }) {
  const { compact, phone } = useLayout();
  const { theme } = useApp();
  return (
    <View
      style={{
        paddingHorizontal: phone ? 16 : compact ? 20 : 27,
        paddingTop: phone ? 14 : 22,
        paddingBottom: 24,
        ...(phone && { backgroundColor: theme.bg }),
      }}
    >
      {children}
    </View>
  );
}
export function SettingsSheet() {
  const { prefs, setPreference, open } = useApp();
  return (
    <Wrap>
      <SheetHeading
        title="Paramètres"
      />
      <MiniTitle text="Préréglages d’affichage" icon="color-palette-outline" />
      <DisplayPresets />
      <MiniTitle text="Lecture" icon="play-circle-outline" />
      <ToggleRow
        title="Lecture automatique"
        description="Lancer la vidéo à l’ouverture du lecteur intégré."
        value={prefs.autoplay}
        onChange={(v) => setPreference("autoplay", v)}
      />
      <View style={{ marginTop: 11 }}>
        <MiniTitle text="Confidentialité" icon="shield-checkmark-outline" />
        <ToggleRow
          title="Mémoriser ma progression"
          description="Retrouver vos reprises rapides sur l’accueil."
          value={prefs.history}
          onChange={(v) => setPreference("history", v)}
        />
        <ToggleRow
          title="Historique des recherches"
          description="Conserver les recherches de ce profil sur cet appareil."
          value={prefs.rememberSearch}
          onChange={(v) => setPreference("rememberSearch", v)}
        />
      </View>
      <View style={{ marginTop: 17 }}>
        <MenuRow
          title="Mon compte Neo-stream"
          icon="person-outline"
          onPress={() => open({ type: "account" })}
        />
        <MenuRow
          title="Ma liste et mon historique"
          icon="bookmark-outline"
          onPress={() => open({ type: "library" })}
        />
        <MenuRow
          title="À propos et crédits"
          sub="Neo-stream · pecorio-dev"
          icon="information-circle-outline"
          onPress={() => open({ type: "credits" })}
        />
      </View>
    </Wrap>
  );
}
export function LibrarySheet() {
  const { theme, account, profile, favorites, progress, open, tv } = useApp();
  if (!account) return null;
  return (
    <Wrap>
      <SheetHeading
        title="Mon espace"
      />
      <Glass
        style={[
          row,
          {
            gap: 13,
            padding: 15,
            borderRadius: 15,
          },
        ]}
      >
        <Avatar size={49} index={profile.color} portraitId={profile.portraitId} />
        <View style={{ flex: 1, gap: 3 }}>
          <T size={18} weight="extra" testID="viewer-name">
            {profile.profileId ? profile.name : account.name}
          </T>
          <T size={11} color={theme.muted}>
            {profile.profileId ? 'Profil de visionnage' : 'Compte connecté'}
          </T>
        </View>
        <IconButton
          label="Modifier mon profil"
          icon="pencil-outline"
          onPress={() => open({ type: "profile" })}
          size={30}
        />
      </Glass>
      <View style={[row, { gap: 10, marginVertical: 15 }]}>
        {(
          [
            {
              title: "Ma liste",
              count: favorites.length,
              icon: "bookmark-outline",
              section: "favorites",
            },
            {
              title: "Historique",
              count: progress.length,
              icon: "time-outline",
              section: "history",
            },
          ] as const
        ).map((tile) => (
          <Click
            key={tile.title}
            label={tv ? `${tile.title}, ${tile.count}` : undefined}
            testID={tv ? `library-${tile.section}` : undefined}
            autoFocus={tv && tile.section === 'favorites'}
            onPress={() => open({ type: "collection", section: tile.section })}
            style={{
              flex: 1,
              padding: 16,
              overflow: 'hidden', borderWidth: 1, borderColor: theme.glassEdge,
              borderRadius: 15,
              gap: 10,
            }}
          >
            <GlassLayer /><View style={[row, { justifyContent: "space-between" }]}>
              <I name={tile.icon} color={theme.accent} size={20} />
              <T size={21} weight="extra">
                {tile.count}
              </T>
            </View>
            <View style={[row, { justifyContent: "space-between" }]}>
              <T size={13} weight="bold">
                {tile.title}
              </T>
              <I name="arrow-forward" size={14} color={theme.faint} />
            </View>
          </Click>
        ))}
      </View>
      <MenuRow
        title="Compte Neo-stream"
        sub={account.email}
        icon="person-outline"
        onPress={() => open({ type: "account" })}
      />
      <MenuRow
        title="Préférences"
        sub="Thème, lecture et confidentialité"
        icon="options-outline"
        onPress={() => open({ type: "settings" })}
      />
      <MenuRow
        title="Crédits de l’application"
        icon="code-slash-outline"
        onPress={() => open({ type: "credits" })}
      />
    </Wrap>
  );
}
export function CollectionSheet({
  section,
}: {
  section: "favorites" | "history";
}) {
  const {
    theme,
    favorites,
    progress,
    history,
    profile,
    clearProgress,
    items,
    open,
    toggleFavorite,
    dismiss,
  } = useApp();
  const [confirmProfile, setConfirmProfile] = useState<typeof profile | null>(null);
  const confirm = confirmProfile === profile;
  const setConfirm = (value: boolean) => setConfirmProfile(value ? profile : null);
  const [tab, setTab] = useState(section);
  const titles = tab === "history" ? history : favorites.flatMap((id) => {
    const item = items.find((v) => v.id === id);
    return item ? [{ item, entry: null }] : [];
  });
  return (
    <Wrap>
      <SheetHeading
        title={tab === "favorites" ? "Ma liste" : "Mon historique"}
      />
      <View style={[row, { gap: 8, marginBottom: 15 }]}>
        <Chip
          label={`Favoris · ${favorites.length}`}
          active={tab === "favorites"}
          onPress={() => {
            setTab("favorites");
            setConfirm(false);
          }}
        />
        <Chip
          label={`Historique · ${progress.length}`}
          active={tab === "history"}
          onPress={() => {
            setTab("history");
            setConfirm(false);
          }}
        />
      </View>
      {titles.length ? (
        titles.map(({ item: m, entry: e }) => {
          return (
            <View
              key={m.id}
              style={[
                row,
                {
                  gap: 11,
                  paddingVertical: 11,
                  borderTopWidth: 1,
                  borderColor: theme.border,
                },
              ]}
            >
              <Click
                label={`Ouvrir ${m.title}`}
                onPress={() =>
                  open({
                    type: tab === "history" && !isEpisodicTitle(m) ? "watch" : "detail",
                    item: m,
                  })
                }
                style={[row, { gap: 12, flex: 1, minWidth: 0 }]}
              >
                <Art
                  source={m.backdrop}
                  style={{ width: 85, height: 55, borderRadius: 6 }}
                />
                <View style={{ flex: 1, gap: 4, minWidth: 0 }}>
                  <T size={13} weight="bold" lines={1}>
                    {m.title}
                  </T>
                  <T size={10} color={theme.muted} lines={1}>
                    {tab === "history" && e
                      ? `${e.label ? e.label + " · " : ""}${Math.max(0, Math.ceil((e.total - e.position) / 60))} min restantes`
                      : `${m.kind} · ${m.year}`}
                  </T>
                  {tab === "history" && e && (
                    <View
                      style={{
                        width: "80%",
                        backgroundColor: theme.elevated,
                        height: 2,
                        borderRadius: 1,
                        marginTop: 3,
                      }}
                    >
                      <View
                        style={{
                          width: `${Math.min(100, (e.position / e.total) * 100)}%`,
                          height: 2,
                          backgroundColor: theme.accent,
                        }}
                      />
                    </View>
                  )}
                </View>
              </Click>
              <IconButton
                label={`Retirer ${m.title}`}
                icon={tab === "history" ? "trash-outline" : "bookmark"}
                color={tab === "favorites" ? theme.accent : theme.muted}
                size={29}
                onPress={() =>
                  tab === "history" ? clearProgress(m.id) : toggleFavorite(m.id)
                }
              />
            </View>
          );
        })
      ) : (
        <Empty
          icon={tab === "favorites" ? "bookmark-outline" : "time-outline"}
          title={
            tab === "favorites"
              ? "Votre liste commence ici"
              : progress.length ? "Fiches d’historique indisponibles" : "Aucune lecture enregistrée"
          }
          description={
            tab === "favorites"
              ? "Ajoutez vos coups de cœur avec le bouton « Ma liste » pour les retrouver ici."
              : progress.length ? "La progression est conservée. Actualisez le catalogue pour réessayer." : "Votre progression s’affichera ici après une lecture dans le lecteur intégré."
          }
          action="Parcourir le catalogue"
          onPress={() => {
            dismiss();
            explore();
          }}
        />
      )}
      {tab === "history" && progress.length > 0 && (
        <View
          style={{
            marginTop: 14,
            borderTopWidth: 1,
            borderColor: theme.border,
            paddingTop: 13,
            gap: 10,
          }}
        >
          {confirm ? (
            <>
              <T weight="semibold" size={13}>
                Effacer tout l’historique de lecture ?
              </T>
              <T size={12} color={theme.muted}>
                Les reprises seront également retirées de l’accueil. Cette
                action est définitive.
              </T>
              <View style={[row, { gap: 8 }]}>
                <Button
                  small
                  label="Annuler"
                  variant="secondary"
                  onPress={() => setConfirm(false)}
                />
                <Button
                  small
                  label="Confirmer"
                  onPress={() => {
                    clearProgress();
                    setConfirm(false);
                  }}
                />
              </View>
            </>
          ) : (
            <Button
              small
              variant="ghost"
              label="Effacer l’historique"
              icon="trash-outline"
              onPress={() => setConfirm(true)}
              style={{ alignSelf: "flex-start" }}
            />
          )}
        </View>
      )}
    </Wrap>
  );
}
function Field({
  label,
  value,
  onChange,
  secure = false,
  email = false,
  placeholder,
  onSubmit,
  preferred = false,
  inputRef, next, id,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  secure?: boolean;
  email?: boolean;
  placeholder?: string;
  onSubmit?: () => void;
  preferred?: boolean;
  inputRef?: React.Ref<Editor>; next?: () => void; id?: string;
}) {
  const { theme, tv } = useApp();
  const { focusProps, focusStyle } = useTvInputFocus(!tv && preferred);
  const { phone } = useLayout();
  return (
    <View style={{ gap: 7 }}>
      <T weight="bold" size={12}>
        {label}
      </T>
      <SheetInput
        {...(tv ? { onFocus: focusProps.onFocus, onBlur: focusProps.onBlur } : focusProps)} ref={inputRef} testID={id ?? 'profile-name'}
        accessibilityLabel={label}
        placeholder={placeholder}
        placeholderTextColor={theme.faint}
        value={value}
        onChangeText={onChange}
        secureTextEntry={secure}
        keyboardType={email ? "email-address" : "default"}
        autoCapitalize={email || secure ? "none" : "words"}
        autoCorrect={false}
        textContentType={
          email ? "emailAddress" : secure ? "password" : "nickname"
        }
        returnKeyType={next ? 'next' : onSubmit ? "done" : "next"}
        onSubmitEditing={next ?? onSubmit}
        style={[
          {
            fontFamily: fonts.medium,
            color: theme.text,
            fontSize: tv ? 22 : 16,
            borderWidth: 1,
            borderRadius: phone ? 6 : 12,
            borderColor: phone ? theme.border : theme.glassEdge,
            backgroundColor: phone ? theme.surface : theme.bg,
            paddingHorizontal: 13,
            minHeight: tv ? 60 : 48,
          },
          focusStyle,
        ]}
      />
    </View>
  );
}
export function ProfileSheet() {
  const { account, authSessionId, profile, reloadProfiles } = useApp();
  useEffect(() => { void reloadProfiles(); }, [reloadProfiles]);
  return account ? <ProfileForm key={JSON.stringify([authSessionId, profile.profileId])} /> : null;
}

function ProfileForm() {
  const { profile, profiles, profilesBusy, profilesError, reloadProfiles, selectProfile, saveProfile, theme, notify, token } = useApp();
  const [draft, setDraft] = useState<{ id: string; name: string; color: number; portraitId?: string | null } | null>(null);
  const [error, setError] = useState("");
  const formVersion = useRef(0);
  // Invalidate in-flight drafts when the sheet closes or the session changes.
  useLayoutEffect(() => () => { formVersion.current++; }, [token]);
  const active = profiles.find((item) => item.id === profile.profileId);
  const creating = !!active && draft?.id === "" && profiles.length < 2;
  const editing = creating ? draft : draft && draft.id === active?.id ? draft : active;
  const name = editing?.name ?? "";
  const color = editing?.color ?? 0;
  const changeDraft = (patch: Partial<{ name: string; color: number }>) => {
    if (profilesBusy || !editing) return;
    setDraft((current) => ({ ...(current?.id === editing.id ? current : editing), ...patch }));
    setError("");
  };
  const save = async () => {
    if (!editing || profilesBusy) return;
    const clean = name.trim();
    if (Array.from(clean).length < 2 || Array.from(clean).length > 24) {
      setError("Choisissez un nom de 2 à 24 caractères.");
      return;
    }
    const version = formVersion.current;
    const isCurrent = () => formVersion.current === version;
    try {
      const ok = creating
        ? await saveProfile({ action: "create", name: clean, color }, { id: draft?.portraitId ?? null, isCurrent })
        : await saveProfile({ action: "update", id: editing.id, name: clean, color });
      if (!ok || !isCurrent()) return;
      setDraft(null);
      setError("");
      notify(creating ? "Profil créé. Vous pouvez le sélectionner." : "Profil mis à jour");
    } catch (cause) {
      if (isCurrent()) setError(messageOf(cause));
    }
  };
  return (
    <Wrap>
      <SheetHeading
        title="Mon profil"
        description="Changer de profil change vos listes et votre reprise, pas votre compte Neo-stream."
      />
      <View style={{ gap: 17 }}>
        {profiles.map((item) => (
          <Button key={item.id}
            label={item.id === active?.id ? `${item.name} · Profil actif` : `Utiliser ${item.name}`}
            icon={item.id === active?.id ? "checkmark" : "person-outline"}
            variant={item.id === active?.id ? "secondary" : "ghost"}
            disabled={profilesBusy}
            onPress={() => { setDraft(null); setError(""); selectProfile(item.id); }} />
        ))}
        {!!profilesError && <>
          <T color={theme.danger} size={13}>{profilesError}</T>
          <Button small label="Réessayer" variant="secondary" loading={profilesBusy} onPress={() => void reloadProfiles()} />
        </>}
        {!profiles.length && profilesBusy && <T color={theme.muted} size={12}>Chargement des profils…</T>}
        {!!active && profiles.length < 2 && !creating && (
          <Button small label="Créer un deuxième profil" icon="add" variant="secondary"
            disabled={profilesBusy} onPress={() => { setDraft({ id: "", name: "", color: 1, portraitId: null }); setError(""); }} />
        )}
        {editing && <>
        <Field
          label={creating ? "Nom du nouveau profil" : "Nom du profil actif"}
          value={name}
          onChange={(s) => changeDraft({ name: s })}
          onSubmit={() => void save()}
        />
        {creating ? <PortraitChooser key="draft" draft={{
          id: draft?.portraitId ?? null,
          color,
          disabled: profilesBusy,
          choose: (id) => {
            if (!profilesBusy) setDraft((current) => current?.id === "" ? { ...current, portraitId: id } : current);
          },
        }} /> : <PortraitChooser key="active" />}
        <T size={12} weight="bold">
          Couleur de l’avatar classique
        </T>
        <View style={[row, { gap: 10 }]}>
          {avatarColors.map((_, i) => (
            <Click
              key={i}
              label={["Graphite", "Sauge", "Lavande", "Océan"][i]}
              selected={color === i}
              onPress={() => changeDraft({ color: i })}
              style={{
                padding: 3,
                borderWidth: 2,
                borderRadius: 28,
                borderColor: color === i ? theme.accent : "transparent",
              }}
            >
              <Avatar size={39} index={i} />
            </Click>
          ))}
        </View>
        {!!error && (
          <T color={theme.danger} size={13}>
            {error}
          </T>
        )}
        <Button label={creating ? "Créer le profil" : "Enregistrer le profil"} icon="checkmark"
          loading={profilesBusy} onPress={() => void save()} />
        </>}
      </View>
    </Wrap>
  );
}
const messageOf = (e: unknown) =>
  e instanceof Error ? e.message : "Opération impossible. Réessayez.";
const sessionIcon = (type: string): IconName =>
  /tv|cast|stb|roku|android.?tv/i.test(type)
    ? "tv-outline"
    : /mobile|phone|ios|android/i.test(type)
      ? "phone-portrait-outline"
      : "desktop-outline";
const formatWhen = (value: string) => {
  if (!value) return "récemment";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleDateString("fr-FR", { day: "2-digit", month: "short" });
};
const privacyUrl = validateLegalUrl(process.env.EXPO_PUBLIC_NEO_PRIVACY_URL);
const deleteAccountUrl = validateLegalUrl(
  process.env.EXPO_PUBLIC_NEO_DELETE_ACCOUNT_URL,
);

function AccountLegalActions() {
  const { theme } = useApp();
  const [failedAction, setFailedAction] = useState<string | null>(null);
  if (!privacyUrl && !deleteAccountUrl) return null;

  const openPage = async (action: string, url: string) => {
    setFailedAction(null);
    try {
      await openOfficialLegalLink(url);
    } catch {
      setFailedAction(action);
    }
  };

  return (
    <View style={{ marginTop: 22 }}>
      <MiniTitle text="Compte et données" icon="shield-checkmark-outline" />
      <T size={12} color={theme.muted} style={{ lineHeight: 18, marginBottom: 10 }}>
        Ces pages s’ouvrent dans le navigateur, sur le site officiel Neo-stream.
        Si le navigateur ne s’ouvre pas, recopiez l’adresse sur un téléphone ou
        un ordinateur.
      </T>
      {[
        {
          key: "privacy",
          title: "Politique de confidentialité",
          url: privacyUrl,
        },
        {
          key: "delete",
          title: "Demander la suppression du compte et des données",
          url: deleteAccountUrl,
        },
      ].map(({ key, title, url }) =>
        url ? (
          <View key={key} style={{ marginBottom: 10 }}>
            <MenuRow
              title={title}
              sub={url}
              subSize={14}
              icon="open-outline"
              onPress={() => void openPage(key, url)}
            />
            {key === "delete" && (
              <T size={12} color={theme.muted} style={{ lineHeight: 18 }}>
                La demande se fait sur le site et ne lance aucune suppression
                depuis l’application. Effacer l’historique de lecture ne
                supprime pas votre compte.
              </T>
            )}
            <Text
              accessibilityLiveRegion="polite"
              style={{ color: theme.text, fontFamily: fonts.regular, fontSize: 12 }}
            >
              {failedAction === key
                ? "Impossible d’ouvrir le navigateur. Recopiez l’adresse ci-dessus."
                : null}
            </Text>
          </View>
        ) : null,
      )}
    </View>
  );
}

export function AccountSheet() {
  const { account, profile, theme, logout, authStep, sessionInfo, loadSessions, revokeSession } = useApp();
  const [error, setError] = useState("");
  const [sessions, setSessions] = useState<SessionInfo[] | null>(null);
  const sessionsLoading = sessions === null;
  const [revoking, setRevoking] = useState("");
  useEffect(() => {
    if (authStep !== "signed-in") return;
    let live = true;
    loadSessions()
      .then((list) => {
        if (live) setSessions(list);
      })
      .catch(() => {
        if (live) setSessions([]);
        if (live) setError("Impossible de charger la liste des appareils.");
      });
    return () => {
      live = false;
    };
  }, [authStep, loadSessions]);
  const revoke = async (id: string) => {
    setRevoking(id);
    setError("");
    try {
      await revokeSession(id);
      setSessions((v) => (v ? v.filter((s) => s.id !== id) : v));
    } catch (e) {
      setError(messageOf(e));
    } finally {
      setRevoking("");
    }
  };
  if (authStep !== 'signed-in' || !account) return null;
  return (
    <Wrap>
      <SheetHeading title="Mon compte" />
        <View style={{ gap: 13 }}>
          <View
            style={[
              row,
              {
                gap: 13,
                padding: 15,
                backgroundColor: theme.bg,
                borderRadius: 11,
                borderWidth: 1,
                borderColor: theme.border,
              },
            ]}
          >
            <View accessible={false} aria-hidden style={{ width: 48, alignItems: 'center' }}>
              <I name="person-circle-outline" size={39} color={theme.muted} />
            </View>
            <View style={{ flex: 1, minWidth: 0, gap: 3 }}>
              <T size={12} color={theme.muted}>Titulaire du compte</T>
              {account.name !== account.email && <T size={18} weight="extra" testID="account-name">
                {account.name}
              </T>}
              <T size={account.name === account.email ? 18 : 13} weight={account.name === account.email ? 'extra' : 'regular'} testID="account-email">{account.email}</T>
              <View style={[row, { gap: 5, marginTop: 3 }]}>
                <I
                  name={
                    account.emailVerified
                      ? "checkmark-circle"
                      : "alert-circle-outline"
                  }
                  size={13}
                  color={account.emailVerified ? theme.accent : theme.faint}
                />
                <T
                  size={11}
                  color={account.emailVerified ? theme.accent : theme.faint}
                >
                  {account.emailVerified
                    ? "Adresse vérifiée"
                    : "Adresse non vérifiée"}
                </T>
              </View>
            </View>
          </View>
          {!!profile.profileId && <View style={[row, { gap: 10 }]}>
            <Avatar size={34} index={profile.color} portraitId={profile.portraitId} />
            <View style={{ flex: 1, minWidth: 0 }}>
              <T size={12} color={theme.muted}>Profil de visionnage</T>
              <T weight="semibold" testID="account-active-profile">{profile.name}</T>
            </View>
          </View>}
          <View
            style={{ borderTopWidth: 1, borderColor: theme.border, paddingTop: 15, gap: 10 }}
          >
            <MiniTitle
              text={`Appareils connectés (${sessionInfo?.active ?? sessions?.length ?? 0}/${sessionInfo?.limit ?? 4})`}
              icon="tv-outline"
            />
            <T size={11} color={theme.muted} style={{ lineHeight: 18 }}>
              Quatre appareils maximum peuvent rester connectés en même temps.
              Déconnectez un appareil pour en libérer un.
            </T>
            {sessionsLoading ? (
              <T size={12} color={theme.muted}>
                Chargement des appareils…
              </T>
            ) : sessions?.length ? (
              sessions.map((s) => (
                <View
                  key={s.id}
                  style={[
                    row,
                    {
                      gap: 11,
                      paddingVertical: 10,
                      borderTopWidth: 1,
                      borderColor: theme.border,
                    },
                  ]}
                >
                  <View
                    style={{ backgroundColor: theme.elevated, padding: 8, borderRadius: 8 }}
                  >
                    <I name={sessionIcon(s.type)} size={17} color={theme.muted} />
                  </View>
                  <View style={{ flex: 1, gap: 3, minWidth: 0 }}>
                    <T size={13} weight="bold" lines={1}>
                      {s.label || "Appareil"}
                    </T>
                    <T size={11} color={theme.muted} lines={1}>
                      {s.current
                        ? `${s.type || "application"} · cet appareil`
                        : `${s.type || "application"} · vu le ${formatWhen(s.lastSeen)}`}
                    </T>
                  </View>
                  {s.current ? (
                    <T size={11} weight="bold" color={theme.accent}>
                      Actuel
                    </T>
                  ) : (
                    <Button
                      small
                      label="Déconnecter"
                      icon="log-out-outline"
                      variant="secondary"
                      loading={revoking === s.id}
                      onPress={() => revoke(s.id)}
                    />
                  )}
                </View>
              ))
            ) : (
              <T size={12} color={theme.muted}>
                Aucun appareil connecté pour le moment.
              </T>
            )}
          </View>
          <Button
            label="Se déconnecter"
            icon="log-out-outline"
            variant="secondary"
            onPress={logout}
          />
        </View>
      {!!error && (
        <T size={13} color={theme.danger} style={{ marginTop: 12 }}>
          {error}
        </T>
      )}
      <AccountLegalActions />
    </Wrap>
  );
}
function CreditPill({ label }: { label: string }) {
  const { theme } = useApp();
  return (
    <View
      style={{
        paddingHorizontal: 11,
        paddingVertical: 6,
        borderRadius: 14,
        backgroundColor: theme.elevated,
        borderWidth: 1,
        borderColor: theme.border,
      }}
    >
      <T size={11} weight="semibold" color={theme.muted}>
        {label}
      </T>
    </View>
  );
}

function TechTile({
  icon,
  label,
  detail,
}: {
  icon: IconName;
  label: string;
  detail: string;
}) {
  const { theme } = useApp();
  return (
    <View
      style={{
        flex: 1,
        alignItems: "center",
        gap: 7,
        paddingVertical: 14,
        paddingHorizontal: 6,
        borderRadius: 12,
        backgroundColor: theme.surface,
        borderWidth: 1,
        borderColor: theme.border,
      }}
    >
      <View
        style={{
          width: 34,
          height: 34,
          borderRadius: 10,
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: theme.soft,
        }}
      >
        <I name={icon} size={17} color={theme.accent} />
      </View>
      <T size={12} weight="bold" style={{ textAlign: "center" }}>
        {label}
      </T>
      <T size={10} color={theme.faint} style={{ textAlign: "center" }}>
        {detail}
      </T>
    </View>
  );
}

export function CreditsSheet() {
  const { theme, notify, open } = useApp();
  const { phone } = useLayout();
  return (
    <Wrap>
      <SheetHeading
        title="À propos"
      />

      {/* Carte d’identité */}
      <Glass
        style={{
          borderRadius: 18,
          paddingVertical: 27,
          paddingHorizontal: 20,
          alignItems: "center",
          gap: 10,
          overflow: "hidden",
          borderWidth: 1,
          borderColor: theme.border,
        }}
      >
        <View style={{ width: 116, height: 116, alignItems: "center", justifyContent: "center" }}>
          <View
            style={{
              position: "absolute",
              width: 116,
              height: 116,
              borderRadius: 58,
              backgroundColor: theme.accent,
              opacity: 0.09,
            }}
          />
          <Image
            accessibilityLabel="Logo officiel Neo-stream"
            source={require("../assets/splash-logo.png")}
            style={{ width: 92, height: 92, borderRadius: 18 }}
            resizeMode="contain"
          />
        </View>
        <T size={27} weight="extra" style={{ letterSpacing: -1.1 }}>
          Neo-stream
        </T>
        <View
          style={{
            paddingHorizontal: 12,
            paddingVertical: 5,
            borderRadius: 13,
            backgroundColor: theme.soft,
            borderWidth: 1,
            borderColor: theme.border,
          }}
        >
          <T size={11} weight="semibold" color={theme.accent}>
            Version 1.0.0
          </T>
        </View>
      </Glass>

      {/* Conception & développement */}
      <View style={{ marginTop: 24 }}>
        <MiniTitle text="Conception & développement" icon="code-slash-outline" />
        <View>
          <T weight="extra" size={22} style={{ letterSpacing: -0.7, marginBottom: 5 }}>
            pecorio-dev
          </T>
          {!phone && <T size={12} color={theme.muted} style={{ lineHeight: 20 }}>
            Une expérience cinématographique pensée pour le mobile, la tablette
            et le grand écran.
          </T>}
        </View>
      </View>

      {/* La sélection découverte */}
      <View style={{ marginTop: 24 }}>
        <MiniTitle text="La sélection découverte" icon="film-outline" />
        <View>
          <T size={12} color={theme.muted} style={{ lineHeight: 21 }}>
            Les affiches et photogrammes appartiennent à leurs ayants droit. La reprise utilise la position enregistrée pour le profil actif.
          </T>
          <View style={[row, { gap: 8, marginTop: 15, flexWrap: "wrap" }]}>
            {["Cinemeta", "TMDB", "Metahub"].map((label) => (
              <CreditPill key={label} label={label} />
            ))}
          </View>
        </View>
      </View>

      {/* Technologie */}
      <View style={{ marginTop: 24 }}>
        <MiniTitle text="Technologie" icon="hardware-chip-outline" />
        <View style={[row, { gap: 10 }]}>
          <TechTile icon="rocket-outline" label="Expo" detail="SDK 57" />
          <TechTile icon="layers-outline" label="React Native" detail="0.86" />
          <TechTile icon="text-outline" label="Manrope et Barlow Condensed" detail="Typographie" />
        </View>
      </View>

      {/* Actions */}
      <View style={{ marginTop: 28, gap: 10 }}>
        <Button
          label="Site officiel Neo-stream"
          icon="open-outline"
          variant="secondary"
          onPress={() => openLink(OFFICIAL_SITE, notify)}
        />
        {hasService && (
          <Button
            label="Mon compte"
            icon="person-outline"
            variant="ghost"
            onPress={() => open({ type: "account" })}
          />
        )}
      </View>
    </Wrap>
  );
}
