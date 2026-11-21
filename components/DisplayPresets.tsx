import React, { useState } from 'react';
import { Platform, TextInput, View } from 'react-native';
import { useApp } from '../lib/store';
import { activePreset, availableName, customLimit, presetBases, presetName, presetNotes } from '../lib/displayPresets';
import { fonts, palettes, phonePalettes, tvPalettes } from '../lib/theme';
import type { DisplayPreset, PresetBase } from '../lib/types';
import { Button, Chip, Click, I, row, T, useTvInputFocus } from './UI';

const phoneName: Record<PresetBase, string> = { cinema: 'Prune', minuit: 'Noir OLED', salon: 'Contraste renforcé' };
const tvName: Record<PresetBase, string> = { cinema: 'Salle obscure', minuit: 'Noir OLED', salon: 'Contraste renforcé' };
const matteNotes: Record<PresetBase, string> = { cinema: 'Surfaces mates.', minuit: 'Fond noir pur.', salon: 'Texte et contours plus contrastés.' };

function Sample({ preset }: { preset: DisplayPreset }) {
  const { phone, tv } = useApp();
  const p = (tv ? tvPalettes : phone ? phonePalettes : palettes)[preset.base];
  return <View aria-hidden style={{ backgroundColor: p.bg, height: 36, width: 55, borderRadius: 6, borderWidth: 1, borderColor: p.glassEdge, padding: 5, gap: 3, justifyContent: 'flex-end' }}>
    <View style={{ width: '48%', height: 3, backgroundColor: p.text, borderRadius: 2 }} />
    <View style={{ height: 10, borderRadius: 3, borderWidth: 1, borderColor: p.glassEdge, backgroundColor: phone || tv ? p.elevated : preset.matte ? p.surface : p.glassGlint }} />
  </View>;
}

export function DisplayPresets() {
  const { theme, phone, tv, prefs: { display }, setPreference } = useApp();
  const current = activePreset(display);
  const matteScreen = phone || tv;
  const names = tv ? tvName : phoneName;
  const title = (p: DisplayPreset) => matteScreen && p.id === p.base ? names[p.base] : p.name;
  const [editing, setEditing] = useState(false), [name, setName] = useState(''), [base, setBase] = useState(current.base), [matte, setMatte] = useState(current.matte);
  const [removing, setRemoving] = useState('');
  const { focusProps, focusStyle } = useTvInputFocus();
  const unique = availableName(name, display.custom) && (!matteScreen || !Object.values(names).some(n => n.toLocaleLowerCase('fr') === presetName(name).toLocaleLowerCase('fr')));
  const allowed = unique && display.custom.length < customLimit;
  const add = () => {
    if (!allowed) return;
    const preset = { id: `local-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`, name: presetName(name), base, matte };
    setPreference('display', { custom: [...display.custom, preset], selected: preset.id }); setEditing(false);
  };
  return <View style={{ gap: 7, marginBottom: 24 }}>
    <T color={theme.muted} size={13} style={{ marginBottom: 4 }}>{Platform.OS === 'web' ? 'Le choix et vos créations restent dans ce navigateur.' : Platform.isTV ? 'Le choix et vos créations restent sur ce téléviseur.' : 'Le choix et vos créations restent sur cet appareil.'}</T>
    {[...presetBases, ...display.custom].map(p => <View key={p.id} style={[row, { gap: 4 }]}>
      <Click selected={display.selected === p.id} label={`Appliquer ${title(p)}`} onPress={() => { setPreference('display', { ...display, selected: p.id }); setRemoving(''); }}
        style={[row, { flex: 1, gap: 12, minHeight: 58, paddingHorizontal: 9, paddingVertical: 6, borderRadius: 10, borderWidth: 1, borderColor: display.selected === p.id ? theme.faint : theme.border, backgroundColor: display.selected === p.id ? theme.elevated : theme.bg }]}>
        <Sample preset={p} /><View style={{ flex: 1, minWidth: 0, gap: 2 }}><T weight="bold" size={14} lines={2}>{title(p)}</T>
          <T color={theme.muted} size={12}>{matteScreen ? (p.id === p.base ? matteNotes[p.base] : `${names[p.base]}, motif ${p.matte ? 'argenté' : 'en couleur'}.`)
            : p.id === p.base ? presetNotes[p.base] : `${presetBases.find(x => x.id === p.base)!.name}, finition ${p.matte ? 'mate' : 'verre'}.`}</T></View>
        <I name={display.selected === p.id ? 'checkmark-circle' : 'ellipse-outline'} size={19} color={theme.muted} />
      </Click>
      {p.id !== p.base && <Click label={`Supprimer ${p.name}`} onPress={() => { setRemoving(p.id); setEditing(false); }} style={{ minWidth: 44, minHeight: 44, alignItems: 'center', justifyContent: 'center' }}><I name="trash-outline" size={18} /></Click>}
    </View>)}
    {!!removing && <View style={{ gap: 7, padding: 9 }}><T>Supprimer « {display.custom.find(p => p.id === removing)?.name} » de cet appareil ?</T>
      <View style={[row, { flexWrap: 'wrap', gap: 8 }]}><Button small label="Confirmer la suppression" onPress={() => { setPreference('display', { custom: display.custom.filter(p => p.id !== removing), selected: display.selected === removing ? current.base : display.selected }); setRemoving(''); }} />
        <Button small variant="secondary" label="Annuler" onPress={() => setRemoving('')} /></View></View>}
    {editing ? <View style={{ padding: 13, borderRadius: 12, gap: 11, borderWidth: 1, borderColor: theme.border, backgroundColor: theme.surface }}>
      <T size={14} weight="bold">Nom du préréglage</T>
      <TextInput {...focusProps} value={name} onChangeText={setName} maxLength={32} accessibilityLabel="Nom du préréglage" placeholder="Ex. Séance du soir" placeholderTextColor={theme.faint}
        style={[{ minHeight: 46, borderWidth: 1, borderColor: theme.faint, borderRadius: 8, paddingHorizontal: 12, fontFamily: fonts.medium, color: theme.text, backgroundColor: theme.bg }, focusStyle]} />
      {!!name.trim() && !unique && <T size={12} color={theme.danger}>Ce nom est déjà utilisé.</T>}
      <T size={13} weight="semibold">Palette</T><View style={[row, { flexWrap: 'wrap', gap: 6 }]}>{presetBases.map(p => <Chip key={p.id} label={title(p)} active={base === p.base} onPress={() => { setBase(p.base); setMatte(p.matte); }} />)}</View>
      <T size={13} weight="semibold">{matteScreen ? 'Motif ASCII' : 'Finition'}</T><View style={[row, { flexWrap: 'wrap', gap: 6 }]}><Chip label={matteScreen ? 'En couleur' : 'Verre'} active={!matte} onPress={() => setMatte(false)} /><Chip label={matteScreen ? 'Argenté' : 'Mate'} active={matte} onPress={() => setMatte(true)} /></View>
      <View style={[row, { flexWrap: 'wrap', gap: 8 }]}><Button small disabled={!allowed} label="Enregistrer et appliquer" onPress={add} /><Button small variant="secondary" label="Annuler" onPress={() => setEditing(false)} /></View>
    </View> : <Button small variant="secondary" icon="add" label="Créer un préréglage" disabled={display.custom.length >= customLimit} onPress={() => { setBase(current.base); setMatte(current.matte); setName(''); setRemoving(''); setEditing(true); }} />}
  </View>;
}
