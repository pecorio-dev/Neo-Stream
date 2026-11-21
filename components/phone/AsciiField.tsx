import React, { memo, useState } from 'react';
import { Platform, StyleSheet, Text, View, type StyleProp, type ViewStyle } from 'react-native';
import { activePreset } from '../../lib/displayPresets';
import { useApp } from '../../lib/store';
import { asciiComposition, type AsciiVariant } from './asciiGeometry';

type Props = { variant?: AsciiVariant; style?: StyleProp<ViewStyle> };
const cellWidth = .603;
const rowHeight = .99;
const monoSpace = Platform.OS === 'web' ? { whiteSpace: 'pre', overflowWrap: 'normal' } as const : undefined;
const silverInk: Record<string, string> = { '#54424F': '#49444D', '#A26E72': '#918D96', '#BE8C80': '#ABA7AE',
  '#FFBD94': '#E6E1DE', '#628F86': '#87968F', '#92DECA': '#EEF5ED' };

/** A static optical print, computed once per crop; never focusable or announced. */
export function AsciiField(props: Props) {
  const { prefs } = useApp();
  return <Print {...props} silver={activePreset(prefs.display).matte} />;
}

const Print = memo(function Print({ variant = 'interference', style, silver }: Props & { silver: boolean }) {
  const [box, setBox] = useState({ width: 0, height: 0 });
  const { columns, rows, layers } = asciiComposition(variant);
  const fontSize = Math.max(box.width / (columns * cellWidth), box.height / (rows * rowHeight));
  const lineHeight = fontSize * rowHeight;
  return <View testID={`ascii-${variant}`} pointerEvents="none" aria-hidden accessible={false}
    importantForAccessibility="no-hide-descendants"
    style={[StyleSheet.absoluteFill, { overflow: 'hidden' }, style]}
    onLayout={({ nativeEvent: { layout: { width, height } } }) => {
      setBox(old => old.width === width && old.height === height ? old : { width, height });
    }}>
    {fontSize > 0 && layers.map(({ color, text }) => <Text key={color} allowFontScaling={false} selectable={false}
      textBreakStrategy="simple" accessibilityElementsHidden style={{
        ...monoSpace,
        position: 'absolute', color: silver ? silverInk[color] : color, fontFamily: Platform.select({ ios: 'Menlo', default: 'monospace' }),
        includeFontPadding: false, fontSize, lineHeight, textAlign: 'left', writingDirection: 'ltr',
        // Yoga gets slack for platform font metrics; the outer frame supplies the crop.
        width: Math.ceil(columns * fontSize * .77),
        left: (box.width - columns * cellWidth * fontSize) / 2,
        top: (box.height - rows * lineHeight) / 2,
      }}>{text}</Text>)}
  </View>;
});
