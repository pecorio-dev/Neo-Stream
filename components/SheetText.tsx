import React from 'react';
import { StyleSheet } from 'react-native';
import { useApp } from '../lib/store';
import { T } from './UI';

/** Ten-foot reading scale, including existing metadata and legal explanations. */
export function SheetText({ size = 14, style, ...props }: React.ComponentProps<typeof T>) {
  const { tv } = useApp();
  const adjusted = tv && size < 20 ? (size <= 12 ? 17 : 20) : size;
  const leading = tv && StyleSheet.flatten(style)?.lineHeight;
  return <T {...props} size={adjusted} style={[style, leading ? { lineHeight: Math.max(leading, Math.round(adjusted * 1.35)) } : undefined]} />;
}
