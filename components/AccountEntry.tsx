import React, { useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, KeyboardAvoidingView, Platform, ScrollView, Text, View, useWindowDimensions, type TextInputProps } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ApiHttpError, hasService as configured } from '../lib/api';
import { useApp } from '../lib/store';
import { fonts } from '../lib/theme';
import { Emblem } from './Brand';
import { SheetInput, type Editor } from './SheetInput';
import { Click, I } from './UI';
import { AsciiField } from './phone/AsciiField';

const ink = { ground: '#0E0A10', surface: '#201A22', edge: '#806C78', paper: '#FAF1F2', muted: '#D1C2CC', error: '#FFB9AC' };
const bytes = (text: string) => Array.from(text).reduce((n, c) => { const cp = c.codePointAt(0)!; return n + (cp < 128 ? 1 : cp < 2048 ? 2 : cp < 65536 ? 3 : 4); }, 0);
type Key = 'email' | 'password' | 'name' | 'code';
const labels: Record<Key, string> = { email: 'Adresse e-mail', password: 'Mot de passe', name: 'Nom', code: 'Code de vérification' };
type Problem = { field?: Key; text: string };

function Action({ id, label, primary, disabled, onPress }: { id: string; label: string; primary?: boolean; disabled?: boolean; onPress: () => void }) {
  const { tv } = useApp();
  const [focus, setFocus] = useState(false);
  return <Click testID={id} label={label} disabled={disabled} onPress={onPress} onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
    style={{ minHeight: tv ? 60 : 48, padding: 9, alignItems: 'center', justifyContent: 'center', borderRadius: 6,
      borderWidth: 2, borderColor: focus ? '#FFAB95' : 'transparent', backgroundColor: primary ? ink.paper : 'transparent' }}>
    <Text style={{ fontFamily: fonts.bold, textAlign: 'center', fontSize: tv ? 21 : 16, color: primary ? ink.ground : ink.paper }}>{label}</Text>
  </Click>;
}

function Field({ field, initial, invalid, inputRef, accessory, ...props }: TextInputProps & {
  field: Key; initial?: boolean; invalid?: boolean; inputRef?: React.Ref<Editor>; accessory?: React.ReactNode;
}) {
  const { tv } = useApp();
  const [focused, setFocused] = useState(false);
  return <View style={{ gap: 6 }}>
    <Text style={{ fontFamily: fonts.semibold, color: ink.muted, fontSize: tv ? 19 : 14 }}>{labels[field]}</Text>
    <View style={{ flexDirection: 'row', gap: 6, alignItems: 'stretch' }}>
      <SheetInput {...props} ref={inputRef} testID={`account-${field}`} nativeID={`entry-${field}`} accessibilityLabel={labels[field]}
        {...(Platform.OS === 'web' && invalid && { 'aria-invalid': true, 'aria-describedby': 'entry-error' })}
        accessibilityState={{ busy: props.editable === false }} tvInitial={initial} autoCorrect={false} importantForAutofill="yes"
        autoCapitalize={field === 'name' ? 'words' : 'none'} onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
        style={{ flex: 1, minWidth: 0, minHeight: tv ? 60 : 50, paddingHorizontal: 14, paddingVertical: 9,
          fontSize: tv ? 22 : 17, fontFamily: fonts.medium, color: ink.paper, backgroundColor: ink.surface, borderRadius: 6,
          borderWidth: 2, borderColor: focused ? ink.paper : invalid ? ink.error : ink.edge, ...(field === 'code' && { letterSpacing: 5 }) }} />
      {accessory}
    </View>
  </View>;
}

export function AccountEntry() {
  const { authStep } = useApp();
  const [create, setCreate] = useState(false), [name, setName] = useState(''), [email, setEmail] = useState('');
  // A different form also discards its password/OTP and timer immediately.
  // Only public drafts survive editing the verification address.
  return <Form key={authStep === 'pending' ? 'verification' : create ? 'registration' : 'login'}
    create={create} setCreate={setCreate} name={name} setName={setName} email={email} setEmail={setEmail} />;
}

type Draft = { create: boolean; setCreate: (v: boolean) => void; name: string; setName: (v: string) => void; email: string; setEmail: (v: string) => void };
function Form({ create, setCreate, name, setName, email, setEmail }: Draft) {
  const { phone, tv, accessState, accessError, canRetryAccess, retryAccess, authStep, pendingEmail, toast, authenticate, register, verifyCode, resendCode, clearPending } = useApp();
  const { width } = useWindowDimensions();
  const wide = !phone && width >= 880;
  const pending = authStep === 'pending';
  const [show, setShow] = useState(false), [password, setPassword] = useState(''), [code, setCode] = useState('');
  const [error, setError] = useState<Problem | null>(null), [busy, setBusy] = useState<'submit' | 'resend' | null>(null);
  const lock = useRef(false), emailInput = useRef<Editor>(null), passwordInput = useRef<Editor>(null);
  const [cooldown, setCooldown] = useState(() => pending ? 30 : 0);
  useEffect(() => {
    if (!pending || !cooldown) return;
    const timer = setTimeout(() => setCooldown(s => Math.max(0, s - 1)), 1000);
    return () => clearTimeout(timer);
  }, [pending, cooldown]);
  const notice = error?.text || (!configured ? 'Le service Neo-stream n’est pas configuré.' : accessError || (pending ? toast : ''));
  useEffect(() => {
    if (notice && Platform.OS === 'ios') AccessibilityInfo.announceForAccessibility(notice);
  }, [notice]);
  const submit = async (action: 'submit' | 'resend' = 'submit') => {
    if (lock.current || !configured || accessState !== 'locked' || (action === 'resend' && (!pending || cooldown))) return;
    const address = (pending ? pendingEmail || email : email).trim();
    if (pending && action === 'submit' && !/^\d{6}$/.test(code)) return setError({ field: 'code', text: 'Saisissez le code à 6 chiffres reçu par e-mail.' });
    if (!pending) {
      const length = Array.from(name.trim()).length;
      if (create && (length < 2 || length > 40)) return setError({ field: 'name', text: 'Indiquez un nom de 2 à 40 caractères.' });
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(address) || bytes(address) > (create ? 100 : 120)) return setError({ field: 'email', text: 'Saisissez une adresse e-mail valide.' });
      if (!password || (create && bytes(password) < 8) || bytes(password) > 200) return setError({ field: 'password', text: bytes(password) > 200 ? 'Le mot de passe est trop long.' : create ? 'Choisissez un mot de passe d’au moins 8 caractères.' : 'Saisissez votre mot de passe.' });
    }
    lock.current = true; setBusy(action); setError(null);
    try {
      if (action === 'resend') { await resendCode(address); setCooldown(30); }
      else if (pending) await verifyCode(address, code);
      else if (create) await register(name.trim(), address, password);
      else await authenticate('login', address, password);
      if (action === 'submit') setPassword('');
    } catch (cause) {
      if (pending && action === 'resend' && cause instanceof ApiHttpError && cause.retryAt > Date.now()) setCooldown(Math.ceil((cause.retryAt - Date.now()) / 1000));
      setError({ text: cause instanceof Error && cause.message ? cause.message : 'Connexion impossible. Réessayez.' });
    } finally { lock.current = false; setBusy(null); }
  };
  const changeMode = () => {
    if (lock.current) return;
    if (pending) { setEmail(pendingEmail || email); clearPending(); } else setCreate(!create);
  };
  const change = (set: (s: string) => void) => (s: string) => { if (!lock.current) { set(s); setError(null); } };
  const editable = !busy, title = pending ? 'Vérifier mon adresse' : create ? 'Créer un compte' : 'Connexion';
  return <View testID="auth-gate" style={{ flex: 1, backgroundColor: ink.ground }}>
    <SafeAreaView style={{ flex: 1 }}><KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', alignItems: 'center', paddingHorizontal: phone ? 22 : 40, paddingVertical: phone ? 28 : 40 }}>
        <View style={{ width: '100%', maxWidth: wide ? 1040 : 480, flexDirection: wide ? 'row' : 'column', alignItems: wide ? 'center' : 'stretch', gap: wide ? 72 : 24 }}>
          <View style={wide ? { flex: 1, gap: 30 } : { flexDirection: 'row', alignItems: 'center', gap: 30 }}>
            <Emblem size={wide ? 108 : 58} />
            <View pointerEvents="none" style={{ height: wide ? 160 : 44, ...(wide ? {} : { flex: 1 }), opacity: .56, overflow: 'hidden' }}><AsciiField variant="fold" /></View>
          </View>
          <View style={[{ gap: tv ? 20 : 15 }, wide && { width: tv ? 490 : 426 }]}>
            <Text accessibilityRole="header" style={{ fontFamily: fonts.display, fontSize: tv ? 62 : 48, color: ink.paper, marginBottom: 4 }}>{title}</Text>
            {configured && accessState === 'locked' && (pending ? <>
              <Text style={{ fontFamily: fonts.medium, fontSize: tv ? 19 : 15, color: ink.muted }}>Code à 6 chiffres pour {pendingEmail || email}</Text>
              <Field key="code" field="code" initial invalid={error?.field === 'code'} value={code} editable={editable}
                 onChangeText={v => change(setCode)(v.replace(/\D/g, '').slice(0, 6))} keyboardType="number-pad" autoComplete="one-time-code" textContentType="oneTimeCode" returnKeyType="done" blurOnSubmit={false} submitBehavior="submit" onSubmitEditing={() => void submit()} />
            </> : <>
              {create && <Field field="name" initial value={name} invalid={error?.field === 'name'} editable={editable} onChangeText={change(setName)} autoComplete="name" textContentType="name"
                returnKeyType="next" blurOnSubmit={false} onSubmitEditing={() => emailInput.current?.focus()} />}
              <Field field="email" initial={!create} inputRef={emailInput} invalid={error?.field === 'email'} value={email} editable={editable} onChangeText={change(setEmail)} autoComplete="email" textContentType="emailAddress"
                keyboardType="email-address" returnKeyType="next" blurOnSubmit={false} onSubmitEditing={() => passwordInput.current?.focus()} />
              <Field field="password" inputRef={passwordInput} invalid={error?.field === 'password'} value={password} editable={editable} onChangeText={change(setPassword)} secureTextEntry={!show}
                 autoComplete={create ? 'new-password' : 'current-password'} textContentType={create ? 'newPassword' : 'password'} returnKeyType="done" blurOnSubmit={false} submitBehavior="submit" onSubmitEditing={() => void submit()}
                accessory={<Click testID="entry-show-password" label={`${show ? 'Masquer' : 'Afficher'} le mot de passe`} selected={show} disabled={!editable} onPress={() => setShow(!show)}
                  style={{ width: tv ? 60 : 48, alignItems: 'center', justifyContent: 'center', borderRadius: 6, backgroundColor: ink.surface }}><I name={show ? 'eye-off-outline' : 'eye-outline'} color={ink.paper} size={tv ? 26 : 22} /></Click>} />
            </>)}
            {!!notice && <Text nativeID="entry-error" accessibilityRole="alert" accessibilityLiveRegion="polite" style={{ color: error || accessError ? ink.error : ink.muted, fontSize: tv ? 18 : 14, fontFamily: fonts.medium }}>{notice}</Text>}
            {configured && accessState === 'locked' && <View style={{ gap: 4 }}>
              <Action id="entry-submit" primary label={busy === 'submit' ? 'Envoi en cours…' : pending ? 'Vérifier le code' : create ? 'Créer un compte' : 'Se connecter'} disabled={!!busy} onPress={() => void submit()} />
              {pending && <Action id="entry-resend" label={cooldown ? `Renvoyer le code (${cooldown} s)` : 'Renvoyer le code'} disabled={!!busy || !!cooldown} onPress={() => void submit('resend')} />}
              <Action id={pending ? 'entry-change-email' : create ? 'entry-login' : 'entry-create'} label={pending ? 'Modifier l’adresse e-mail' : create ? 'Connexion' : 'Créer un compte'} disabled={!!busy} onPress={changeMode} />
               {canRetryAccess && !pending && <Action id="entry-retry" label="Réessayer la vérification de session" disabled={!!busy} onPress={retryAccess} />}
            </View>}
          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView></SafeAreaView>
  </View>;
}
