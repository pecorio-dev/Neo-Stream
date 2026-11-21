import { requireOptionalNativeModule } from 'expo';
import type { VideoPlayer } from 'expo-video';
import { Platform } from 'react-native';

type VideoQuality = {
  heights: number[];
  selectedHeight: number | null;
};

type AndroidVideoQuality = {
  getQuality(player: VideoPlayer): Promise<VideoQuality>;
  selectHeight(player: VideoPlayer, height: number | null): Promise<boolean>;
};

export const androidVideoQuality = Platform.OS === 'android'
  ? requireOptionalNativeModule<AndroidVideoQuality>('NeoVideoQuality')
  : null;
