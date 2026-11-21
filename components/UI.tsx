import React, { useRef, useState } from "react";
import {
  ActivityIndicator,
  Platform,
  Pressable,
  StyleProp,
  Text,
  TextStyle,
  View,
  ViewStyle,
  useWindowDimensions,
} from "react-native";
import Ionicons from "@expo/vector-icons/Ionicons";
import { Image, ImageProps } from "expo-image";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { useApp } from "../lib/store";
import { fonts, phoneControl } from "../lib/theme";
import { sceneMetrics } from "../lib/layout";
import { Theme } from "../lib/types";
import { GlassLayer } from './Glass';
import { useTvStop } from './tv/TvFocus';
export type IconName = React.ComponentProps<typeof Ionicons>["name"];
export function I({
  name,
  size = 20,
  color,
}: {
  name: IconName;
  size?: number;
  color?: string;
}) {
  const { theme } = useApp();
  return (
    <Ionicons
      aria-hidden
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      name={name}
      size={size}
      color={color ?? theme.text}
    />
  );
}
export function T({
  children,
  size = 14,
  color,
  weight = "regular",
  style,
  lines,
  role,
  testID,
}: {
  children: React.ReactNode;
  size?: number;
  color?: string;
  weight?: keyof typeof fonts;
  style?: StyleProp<TextStyle>;
  lines?: number;
  role?: "header" | "text";
  testID?: string;
}) {
  const { theme, phone } = useApp();
  return (
    <Text
      testID={testID}
      accessibilityRole={role}
      numberOfLines={lines}
      style={[
        {
          color: color ?? theme.text,
          fontFamily: fonts[phone && weight === 'display' ? 'extra' : weight],
          fontSize: size,
        },
        style,
      ]}
    >
      {children}
    </Text>
  );
}
export function Art({
  source,
  style,
  fit = "cover",
  position = "center",
  priority = "normal",
  label,
}: {
  source: number | string;
  style?: ImageProps["style"];
  fit?: ImageProps["contentFit"];
  position?: ImageProps["contentPosition"];
  priority?: ImageProps["priority"];
  label?: string;
}) {
  return (
    <Image
      source={typeof source === "string" ? { uri: source } : source}
      style={style}
      contentFit={fit}
      contentPosition={position}
      cachePolicy="memory-disk"
      priority={priority}
      accessibilityLabel={label}
      transition={0}
      recyclingKey={String(source)}
    />
  );
}
export function useLayout() {
  const { phone, tv } = useApp();
  const { width: windowWidth, height, fontScale } = useWindowDimensions();
  const { left, right } = useSafeAreaInsets();
  return { phone, tv, windowWidth, height, fontScale, ...sceneMetrics(windowWidth - left - right, phone, tv) };
}
/* -------------------------------------------------------------------------- */
/* Base de focus TV — un seul endroit pour toute la logique.                   */
/* Android TV cible : les props React Native standard suffisent, sans fork.    */
/* Sur les autres plateformes ces props sont ignorées (tvOS) ou remplacées     */
/* par le :focus-visible global du web (voir App.tsx).                         */
/* -------------------------------------------------------------------------- */

/** Props de focus optionnelles, réutilisables par tous les contrôles. */
export type FocusProps = {
  testID?: string;
  /** Optional mounted Pressable ref for active TV sub-panels restoring their own trigger. */
  controlRef?: React.RefObject<React.ComponentRef<typeof Pressable> | null>;
  /** Premier élément à recevoir le focus de la télécommande (hasTVPreferredFocus). */
  autoFocus?: boolean;
  /** Navigation directionnelle explicite (ids natifs Android). */
  nextFocusDown?: number;
  nextFocusUp?: number;
  nextFocusLeft?: number;
  nextFocusRight?: number;
};

/** Props natives de focus. Les nextFocus* ne sont pas typés sur Pressable : cast local. */
function tvFocusProps(focus: FocusProps, tv = false, disabled = false) {
  return {
    focusable: !disabled,
    // ReactViewManager.setFocusable(false) clears clicks but deliberately leaves isFocusable intact.
    ...(tv && Platform.OS === 'android' && { accessible: !disabled }),
    hasTVPreferredFocus: !tv && !!focus.autoFocus,
    ...(tv && Platform.OS === 'web' && focus.autoFocus && { dataSet: { tvInitial: 'true' } }),
    ...({
      nextFocusDown: focus.nextFocusDown,
      nextFocusUp: focus.nextFocusUp,
      nextFocusLeft: focus.nextFocusLeft,
      nextFocusRight: focus.nextFocusRight,
    } as any),
  };
}

/** No zoom or change in control size as the remote moves between items. */
function ringStyle(theme: Theme, focused: boolean, tv = false): ViewStyle | false {
  return (
    focused &&
    Platform.OS !== "web" && {
      outlineColor: theme.accent,
      outlineWidth: tv ? 4 : 3,
      outlineOffset: tv ? -4 : -3,
      ...(tv && { boxShadow: `inset 0 0 0 6px ${theme.onAccent}` }),
    }
  );
}

/** Helper minimal pour les TextInput : même anneau de focus que les boutons. */
export function useTvInputFocus(preferred = false) {
  const { theme, tv } = useApp();
  const [focused, setFocused] = useState(false);
  return {
    focusProps: {
      ...(tv ? { focusable: true } : tvFocusProps({ autoFocus: preferred })),
      onFocus: () => setFocused(true),
      onBlur: () => setFocused(false),
    },
    focusStyle: ringStyle(theme, focused, tv),
  };
}

export function Click({
  children,
  onPress,
  label,
  style,
  disabled = false,
  selected,
  testID,
  onFocus,
  onBlur,
  onHoverIn,
  onHoverOut,
  focusBeforePress = false,
  controlRef,
  autoFocus,
  nextFocusDown,
  nextFocusUp,
  nextFocusLeft,
  nextFocusRight,
}: {
  children: React.ReactNode;
  onPress: () => void;
  label?: string;
  style?:
    | StyleProp<ViewStyle>
    | ((state: { pressed: boolean }) => StyleProp<ViewStyle>);
  disabled?: boolean;
  selected?: boolean;
  /** Optionnels : permettent aux cartes d'afficher leurs actions au focus TV. */
  onFocus?: () => void;
  onBlur?: () => void;
  onHoverIn?: () => void;
  onHoverOut?: () => void;
  /** On web, let Modal's focus trap remember this exact opener. */
  focusBeforePress?: boolean;
} & FocusProps) {
  const { theme, tv } = useApp();
  const [focused, setFocused] = useState(false);
  const localRef = useRef<React.ComponentRef<typeof Pressable>>(null);
  const ref = controlRef ?? localRef;
  const remember = useTvStop(ref, testID || label, !!autoFocus, tv && !disabled);
  return (
    <Pressable
      ref={ref}
      {...tvFocusProps({
        autoFocus,
        nextFocusDown,
        nextFocusUp,
        nextFocusLeft,
        nextFocusRight,
      }, tv, disabled)}
      onFocus={() => {
        remember();
        setFocused(true);
        onFocus?.();
      }}
      onBlur={() => {
        setFocused(false);
        onBlur?.();
      }}
      onHoverIn={onHoverIn}
      onHoverOut={onHoverOut}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled, selected }}
      aria-pressed={selected}
      disabled={disabled}
      testID={testID}
      onPress={(event) => {
        event.stopPropagation();
        remember();
        if (focusBeforePress && Platform.OS === "web") ref.current?.focus();
        onPress();
      }}
      style={({ pressed }) => [
        typeof style === "function" ? style({ pressed }) : style,
        pressed && { opacity: 0.78 },
        disabled && { opacity: 0.45 },
        ringStyle(theme, focused, tv),
      ]}
    >
      {children}
    </Pressable>
  );
}
export function Button({
  label,
  accessibilityLabel,
  onPress,
  icon,
  variant = "primary",
  style,
  small = false,
  disabled = false,
  loading = false,
  testID,
  controlRef,
  autoFocus,
  nextFocusDown,
  nextFocusUp,
  nextFocusLeft,
  nextFocusRight,
}: {
  label: string;
  accessibilityLabel?: string;
  onPress: () => void;
  icon?: IconName;
  variant?: "primary" | "silver" | "secondary" | "glass" | "ghost";
  style?: StyleProp<ViewStyle>;
  small?: boolean;
  disabled?: boolean;
  loading?: boolean;
} & FocusProps) {
  const { theme, phone, tv } = useApp();
  const [hover, setHover] = useState(false);
  const [focused, setFocused] = useState(false);
  const localRef = useRef<React.ComponentRef<typeof Pressable>>(null);
  const ref = controlRef ?? localRef;
  const remember = useTvStop(ref, testID || accessibilityLabel || label, !!autoFocus, tv && !(disabled || loading));
  const primary = variant === "primary" || variant === 'silver',
    glass = variant === "glass";
  const color = phone ? (primary ? theme.onAccent : theme.text) : variant === 'silver' ? '#101010' : primary ? theme.onAccent : glass ? "#fff" : theme.text;
  return (
    <Pressable
      ref={ref}
      testID={testID}
      {...tvFocusProps({
        autoFocus,
        nextFocusDown,
        nextFocusUp,
        nextFocusLeft,
        nextFocusRight,
      }, tv, disabled || loading)}
      onFocus={() => { remember(); setFocused(true); }}
      onBlur={() => setFocused(false)}
      onHoverIn={() => setHover(true)}
      onHoverOut={() => setHover(false)}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      accessibilityState={{ disabled: disabled || loading, busy: loading }}
      disabled={disabled || loading}
      onPress={() => { remember(); onPress(); }}
      style={({ pressed }) => [
        {
          flexDirection: "row",
          alignItems: "center",
          justifyContent: "center",
          gap: 9,
          minHeight: small ? 44 : 48,
          borderRadius: 24,
          paddingHorizontal: small ? 15 : 20,
          paddingVertical: 6,
          maxWidth: '100%',
          overflow: 'hidden',
          backgroundColor: variant === 'silver' ? '#F5F5F2' : primary
            ? theme.accent
            : glass
              ? "transparent"
              : variant === "ghost"
                ? "transparent"
                : 'transparent',
          borderWidth: 1,
          borderColor: hover ? color : glass ? "rgba(255,255,255,.3)" : primary || variant === 'ghost' ? 'transparent' : theme.border,
          opacity: disabled ? 0.48 : pressed ? 0.76 : 1,
        },
        style,
        phone && {
          minHeight: phoneControl.min, borderRadius: phoneControl.radius,
          backgroundColor: primary ? theme.accent : variant === 'ghost' ? 'transparent' : theme.elevated,
          borderColor: hover ? (primary ? theme.text : theme.accent) : primary || variant === 'ghost' ? 'transparent' : theme.border,
        },
        ringStyle(theme, focused, tv),
      ]}
    >
      {!phone && (glass || variant === 'secondary') && <GlassLayer dark={glass} />}
      {loading ? (
        <ActivityIndicator size="small" color={color} />
      ) : icon ? (
        <I name={icon} size={small ? 15 : 17} color={color} />
      ) : null}
      <T weight="bold" size={small ? 12 : 14} color={color} style={{ flexShrink: 1, textAlign: 'center' }}>
        {label}
      </T>
    </Pressable>
  );
}
export function IconButton({
  icon,
  onPress,
  label,
  disabled,
  size = 44,
  color,
  glass = false,
  style,
  testID,
  controlRef,
  autoFocus,
  nextFocusDown,
  nextFocusUp,
  nextFocusLeft,
  nextFocusRight,
}: {
  icon: IconName;
  onPress: () => void;
  label: string;
  disabled?: boolean;
  size?: number;
  color?: string;
  glass?: boolean;
  style?: StyleProp<ViewStyle>;
} & FocusProps) {
  const { theme, phone } = useApp();
  return (
    <Click
      onPress={onPress}
      label={label}
      disabled={disabled}
      testID={testID}
      controlRef={controlRef}
      autoFocus={autoFocus}
      nextFocusDown={nextFocusDown}
      nextFocusUp={nextFocusUp}
      nextFocusLeft={nextFocusLeft}
      nextFocusRight={nextFocusRight}
      style={[
        {
          height: Math.max(44, size),
          width: Math.max(44, size),
          borderRadius: Math.max(44, size) / 2,
          alignItems: "center",
          justifyContent: "center",
          borderWidth: 1,
          borderColor: glass ? "rgba(255,255,255,.25)" : theme.border,
          overflow: 'hidden',
          backgroundColor: glass ? 'transparent' : theme.surface,
        },
        style,
        phone && { minWidth: phoneControl.min, minHeight: phoneControl.min, borderRadius: phoneControl.radius, borderColor: theme.border, backgroundColor: theme.elevated },
      ]}
    >
      {!phone && glass && <GlassLayer dark />}
      <I
        name={icon}
        size={Math.max(17, size * 0.46)}
        color={color ?? (phone ? theme.text : glass ? "#fff" : theme.muted)}
      />
    </Click>
  );
}
export function Chip({
  label,
  active,
  onPress,
  icon,
  testID,
  controlRef,
  autoFocus,
  nextFocusDown,
  nextFocusUp,
  nextFocusLeft,
  nextFocusRight,
}: {
  label: string;
  active?: boolean;
  onPress: () => void;
  icon?: IconName;
} & FocusProps) {
  const { theme, phone } = useApp();
  return (
    <Click
      label={label}
      onPress={onPress}
      selected={active}
      testID={testID}
      controlRef={controlRef}
      autoFocus={autoFocus}
      nextFocusDown={nextFocusDown}
      nextFocusUp={nextFocusUp}
      nextFocusLeft={nextFocusLeft}
      nextFocusRight={nextFocusRight}
      style={{
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "center",
        gap: 6,
        paddingHorizontal: 14,
        paddingVertical: 6,
        minHeight: phone ? phoneControl.min : 44,
        borderRadius: phone ? phoneControl.radius : 22,
        borderWidth: 1,
        borderColor: active ? theme.accent : theme.glassEdge,
        backgroundColor: active ? theme.accent : phone ? theme.surface : 'transparent',
      }}
    >
      {icon && (
        <I name={icon} color={active ? theme.onAccent : theme.muted} size={15} />
      )}
      <T
        size={12}
        color={active ? theme.onAccent : theme.muted}
        weight="semibold"
      >
        {label}
      </T>
    </Click>
  );
}
export function PageHeading({ title, action }: { title: string; action?: React.ReactNode }) {
  const { compact, phone, tv, inner } = useLayout();
  return (
    <View style={[row, { gap: 12, justifyContent: 'space-between', paddingTop: compact ? 16 : 30, paddingBottom: tv || compact ? 16 : 22 }]}>
      <T role="header" weight={tv ? 'extra' : 'display'} size={tv ? Math.min(50, Math.max(32, inner * .043)) : phone ? 32 : compact ? 38 : 56} style={{ letterSpacing: -0.7, flexShrink: 1 }}>{title}</T>
      {action}
    </View>
  );
}

export function SectionHeader({
  title,
  icon,
  action,
  onPress,
  children,
}: {
  title: string;
  icon?: IconName;
  action?: string;
  onPress?: () => void;
  children?: React.ReactNode;
}) {
  const { theme } = useApp();
  const { compact, phone } = useLayout();
  return (
    <View
      style={{
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 8,
        marginBottom: 10,
        minHeight: 28,
      }}
    >
      <View
        style={{
          flexDirection: "row",
          alignItems: "center",
          gap: 10,
          flexShrink: 1,
        }}
      >
        {icon && (
          <I name={icon} size={compact ? 20 : 22} color={theme.muted} />
        )}
        <T
          role="header"
          size={phone ? 21 : compact ? 28 : 36}
          weight="display"
          style={{ letterSpacing: -0.4, flexShrink: 1 }}
        >
          {title}
        </T>
        {children}
      </View>
      {action && onPress && (
        <Click
          label={action}
          onPress={onPress}
          style={{
            flexDirection: "row",
            alignItems: "center",
            gap: 5,
            minHeight: phone ? phoneControl.min : 44,
          }}
        >
          <T size={12} color={theme.accent} weight="semibold">
            {action}
          </T>
          <I name="chevron-forward" size={15} color={theme.accent} />
        </Click>
      )}
    </View>
  );
}
export function Kicker({
  children,
  icon,
}: {
  children: React.ReactNode;
  icon?: IconName;
}) {
  const { theme } = useApp();
  return (
    <View style={{ flexDirection: "row", gap: 8, alignItems: "center" }}>
      {icon && <I name={icon} size={14} color={theme.accent} />}
      <T
        weight="extra"
        color={theme.accent}
        size={10}
        style={{ letterSpacing: 2.2 }}
      >
        {children}
      </T>
    </View>
  );
}
export function Empty({
  icon = "film-outline",
  title,
  description,
  action,
  onPress,
}: {
  icon?: IconName;
  title: string;
  description: string;
  action?: string;
  onPress?: () => void;
}) {
  const { theme } = useApp();
  return (
    <View
      style={{
        alignItems: "center",
        paddingHorizontal: 20,
        paddingVertical: 42,
        gap: 10,
      }}
    >
      <View
        style={{
          width: 56,
          height: 56,
          borderRadius: 18,
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: theme.soft,
          marginBottom: 5,
        }}
      >
        <I name={icon} size={26} color={theme.accent} />
      </View>
      <T size={26} weight="display" role="header" style={{ textAlign: "center" }}>
        {title}
      </T>
      <T
        color={theme.muted}
        size={13}
        style={{ textAlign: "center", maxWidth: 380, lineHeight: 21 }}
      >
        {description}
      </T>
      {action && onPress && (
        <Button
          small
          label={action}
          onPress={onPress}
          variant="secondary"
          style={{ marginTop: 6 }}
        />
      )}
    </View>
  );
}
export const row: ViewStyle = { flexDirection: "row", alignItems: "center" };
export const fill = {
  position: "absolute",
  top: 0,
  bottom: 0,
  left: 0,
  right: 0,
} as const;
export const webTransition =
  Platform.OS === "web"
    ? ({
        transitionProperty: "background-color, transform, border-color",
        transitionDuration: "150ms",
      } as any)
    : {};
