import React from "react";
import { Image, Text, View } from "react-native";
import Svg, { Circle, Path, Rect } from "react-native-svg";
import { fonts } from "../lib/theme";
import { Image as PortraitImage } from 'expo-image';
import { portraitById } from '../lib/portraits';

const emblemSource = require("../assets/splash-logo.png");

export function Emblem({ size = 34 }: {
  size?: number;
  /** @deprecated The official logo is not tinted. */
  color?: string;
}) {
  return (
    <Image
      accessibilityLabel="Neo-stream"
      source={emblemSource}
      style={{ width: size, height: size }}
      resizeMode="contain"
    />
  );
}
export function Brand({
  small = false,
  color = "#f8f8f6",
}: {
  small?: boolean;
  color?: string;
  /** @deprecated The official logo is not tinted. */
  accent?: string;
}) {
  return (
    <View
      style={{ flexDirection: "row", alignItems: "center", gap: small ? 7 : 9 }}
    >
      <Emblem size={small ? 24 : 34} />
      <Text
        style={{
          fontFamily: fonts.extra,
          fontSize: small ? 16 : 22,
          letterSpacing: -1.05,
          color,
        }}
      >
        Neo<Text style={{ fontFamily: fonts.medium }}>-stream</Text>
      </Text>
    </View>
  );
}
export const avatarColors = [
  ["#484848", "#C9C9C5"],
  ["#64766c", "#b5d4b9"],
  ["#6f638a", "#ccb9eb"],
  ["#536a85", "#a8c8e8"],
];
export function Avatar({
  size = 35,
  index = 0,
  portraitId,
}: {
  size?: number;
  index?: number;
  portraitId?: string;
}) {
  const portrait = portraitId && portraitById.get(portraitId);
  if (portrait) return <PortraitImage source={portrait.image} testID={`avatar-${portrait.id}`} accessibilityLabel={portrait.name} contentFit="cover" recyclingKey={portrait.id}
    style={{ width: size, height: size, borderRadius: size / 2 }} />;
  const c = avatarColors[index % 4] || avatarColors[0];
  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        overflow: "hidden",
      }}
    >
      <Svg width={size} height={size} viewBox="0 0 64 64">
        <Rect width="64" height="64" fill={c[1]} />
        <Circle cx="51" cy="12" r="21" fill={c[0]} opacity={0.28} />
        <Path d="M2 68Q5 47 23 44l17-1q19 1 24 25Z" fill="#303a36" />
        <Path d="M25 40h13v12l-7 4-8-8Z" fill="#bf8053" />
        <Path
          d="M19 25q1-15 15-15 12 1 13 13l-1 11-5 9-9 4-9-5-4-10Z"
          fill="#d99a6e"
        />
        <Path
          d="M18 32q-2-3-3-8 1-15 12-17 6-6 12-3l8 6 4-1-2 8-5 5-4-7-3 5-10 2-3 6-2-5-3 2 2 8Z"
          fill="#342b24"
        />
        <Path
          d="m31 32 4-1m6-1 4-1"
          fill="none"
          stroke="#3d3028"
          strokeWidth="2"
          strokeLinecap="round"
        />
        <Path
          d="m38 31 1 6-3 1m-4 2q4 2 8-1"
          fill="none"
          stroke="#8e593e"
          strokeWidth="1.3"
          strokeLinecap="round"
        />
        <Path d="m23 45 9 10-4 8-9-14m22-4-9 10 5 7 8-14" fill="#46544b" />
      </Svg>
    </View>
  );
}
