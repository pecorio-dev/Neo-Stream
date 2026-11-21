import React, { useEffect, useImperativeHandle, useRef, useState } from 'react';
import { Platform, Pressable, TextInput, type TextInputProps } from 'react-native';
import { useApp } from '../lib/store';
import { Click, T } from './UI';
import { requestTvControlFocus } from './tv/TvFocus';

export type Editor = { focus: () => void };
/** On Android TV, travelling through a form must not summon the keyboard. OK enters editing. */
export function SheetInput({ ref, tvInitial = false, ...props }: TextInputProps & { ref?: React.Ref<Editor>; tvInitial?: boolean }) {
  const { tv, theme } = useApp();
  const gated = tv && Platform.OS === 'android';
  const [editing, setEditing] = useState(false);
  const input = useRef<TextInput>(null);
  const activator = useRef<React.ComponentRef<typeof Pressable>>(null);
  useEffect(() => {
    if (!tv || !tvInitial) return;
    const frame = requestAnimationFrame(() => {
      if (gated) requestTvControlFocus(activator.current);
      else input.current?.focus();
    });
    return () => cancelAnimationFrame(frame);
  }, [gated, tv, tvInitial]);
  useImperativeHandle(ref, () => ({ focus: () => { if (gated && !editing) setEditing(true); else input.current?.focus(); } }), [gated, editing]);
  if (gated && !editing) return <Click controlRef={activator} autoFocus={tvInitial} disabled={props.editable === false} label={props.accessibilityLabel} testID={`${props.testID}-activate`} onPress={() => setEditing(true)}
    style={{ flexGrow: 1, minHeight: 56, paddingHorizontal: 16, justifyContent: 'center', backgroundColor: theme.elevated, borderWidth: 1, borderColor: theme.border, borderRadius: 8 }}>
    <T size={20} lines={1} color={props.value ? theme.text : theme.muted}>{props.value ? (props.secureTextEntry ? '••••••••' : props.value) : props.placeholder || props.accessibilityLabel}</T>
  </Click>;
  return <TextInput {...props} {...(tv && tvInitial && Platform.OS === 'web' && { dataSet: { tvInitial: 'true' } })} ref={input} autoFocus={gated ? editing : props.autoFocus}
    onBlur={e => { props.onBlur?.(e); if (gated) setEditing(false); }} />;
}
