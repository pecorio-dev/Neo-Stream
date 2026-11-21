import React, { useState } from 'react';
import { FlatList, RefreshControl, ScrollView, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import type { Channel } from '../lib/types';
import { useApp } from '../lib/store';
import { ControlFrame, Footer, OptionBand } from '../components/Browse';
import { useIndexLayout, useResultFocus } from '../components/TitleIndex';
import { GlassLayer } from '../components/Glass';
import { PhoneFooter, PhoneHeading } from '../components/phone/PhoneHome';
import { Button, Chip, Click, Empty, I, PageHeading, row, SectionHeader, T } from '../components/UI';

function ChannelMark({ channel, size = 62 }: { channel: Channel; size?: number }) {
  return <LinearGradient colors={channel.colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }}
    style={{ width: size, height: size, padding: 3, borderRadius: size === 62 ? 12 : 6, alignItems: 'center', justifyContent: 'center' }}>
    <T weight="extra" color="#FFF" size={channel.mark.includes('\n') || channel.mark.length > 6 ? 15 : 21} lines={2} style={{ letterSpacing: -.6, textAlign: 'center' }}>{channel.mark}</T>
  </LinearGradient>;
}

function Station({ channel, width }: { channel: Channel; width: number }) {
  const { open, theme, tv } = useApp();
  const { props, focused } = useResultFocus(() => open({ type: 'channel', channel }));
  return <Click {...props} label={`Ouvrir ${channel.name}`} testID={`${tv ? 'station-board-cell' : 'station-index-row'}-${channel.id}`} style={[{
    width, gap: tv ? 12 : 10, minHeight: tv ? 142 : 77, padding: tv ? 14 : 3,
    paddingVertical: tv ? 14 : 10, borderColor: focused ? theme.accent : theme.border,
    borderWidth: tv ? 2 : 0, borderBottomWidth: tv ? 2 : 1, borderRadius: tv ? 8 : 0,
    backgroundColor: tv ? theme.surface : theme.bg }, !tv && row]}>
    <View style={[row, { justifyContent: 'space-between' }]}><ChannelMark channel={channel} size={tv ? 66 : 48} />
      {tv && <I name="play-circle-outline" color={theme.accent} size={30} />}</View>
    <View style={{ flex: 1, minWidth: 0, gap: 3 }}>
      <T weight="bold" size={tv ? 24 : 16} lines={2}>{channel.name}</T>
      <T color={theme.muted} size={tv ? 17 : 13} lines={2}>{[channel.category, channel.description].filter(Boolean).join(' · ')}</T>
    </View>{!tv && <I name="play-circle-outline" size={24} color={theme.accent} />}
  </Click>;
}

export default function Live() {
  const { theme, channels, open, refresh, refreshing, loadMore, hasMoreChannels, channelDirectoryError } = useApp();
  const { inner, pad, gap, phone, tv, columns, cellWidth } = useIndexLayout();
  const width = inner >= 750 ? Math.floor((inner - gap) / 2) : inner;
  const [category, setCategory] = useState('Toutes');
  const [limit, setLimit] = useState(12);
  const categories = ['Toutes', ...new Set(channels.map(c => c.category))];
  const shown = channels.filter(c => category === 'Toutes' || c.category === category);
  const page = shown.slice(0,limit);
  const sections = Array.from(new Set(page.map(c => c.category)));
  const load = () => {
    if (limit < shown.length) setLimit(n => n + 12);
    else if (hasMoreChannels) void loadMore('channels');
  };
  const select = (c: string) => { setCategory(c); setLimit(12); };
  const empty = <Empty icon="radio-outline" title="Aucune chaîne dans cette catégorie" description="Sélectionnez Toutes pour afficher les autres chaînes." action="Toutes les chaînes" onPress={() => select('Toutes')} />;
  const footer = <View>{(limit < shown.length || hasMoreChannels) && <Button label="Afficher plus de chaînes" variant="secondary" onPress={load} style={{ alignSelf: 'center', minHeight: 48 }} />}<View style={{ marginHorizontal: -pad }}>{phone ? <PhoneFooter /> : <Footer />}</View></View>;
  const refreshControl = <RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={theme.accent} />;
  if (phone || tv) return <FlatList key={columns} testID="live-directory" data={page} keyExtractor={c => c.id} numColumns={columns}
    style={{ flex: 1, backgroundColor: theme.bg }} contentContainerStyle={{ paddingHorizontal: pad }} columnWrapperStyle={columns > 1 ? { gap, marginBottom: 14 } : undefined}
    ListHeaderComponent={<View style={{ paddingBottom: 12 }}>
      {phone ? <PhoneHeading title="En direct" trace variant="fold" /> : <PageHeading title="En direct" />}
      <ControlFrame testID="live-controls"><OptionBand name="Catégories de chaînes" testID="station-categories" options={categories} value={category} onChange={select} /></ControlFrame>
      <View style={[row, { justifyContent: 'space-between', marginTop: 18, gap: 8 }]}><T role="header" weight="bold" size={tv ? 27 : 20} style={{ flexShrink: 1 }}>{category === 'Toutes' ? 'Toutes les chaînes' : category}</T>
        <T color={theme.muted} size={tv ? 18 : 13}>{shown.length} chaîne{shown.length > 1 ? 's' : ''}</T></View>
      {!!channelDirectoryError && <T color={theme.muted} size={tv ? 18 : 14}>{channelDirectoryError}</T>}
    </View>}
    renderItem={({ item }) => <Station channel={item} width={cellWidth} />} ListEmptyComponent={empty} ListFooterComponent={footer}
    onEndReached={load} onEndReachedThreshold={.3} initialNumToRender={12} windowSize={6} showsVerticalScrollIndicator={false} refreshControl={refreshControl} />;
  return <FlatList testID="live-directory" data={sections} keyExtractor={s => s} style={{ flex: 1, backgroundColor: theme.bg }} contentContainerStyle={{ paddingHorizontal: pad }}
    ListHeaderComponent={<View style={{ paddingBottom: 22 }}><PageHeading title="En direct" />
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
        {categories.map(c => <Chip key={c} label={c} active={c === category} onPress={() => select(c)} />)}
      </ScrollView>
      {!!channelDirectoryError && <T size={12} color={theme.muted} style={{ marginTop: 12 }}>{channelDirectoryError}</T>}
    </View>}
    renderItem={({ item: section }) => <View style={{ marginBottom: 24 }}><SectionHeader title={section} />
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap }}>{page.filter(c => c.category === section).map(c =>
        <Click focusBeforePress key={c.id} label={`Ouvrir ${c.name}`} onPress={() => open({ type: 'channel', channel: c })}
          style={[row, { width, minHeight: 88, padding: 12, gap: 12, borderWidth: 1, borderColor: theme.glassEdge, borderRadius: 15, overflow: 'hidden' }]}>
          <GlassLayer /><ChannelMark channel={c} /><View style={{ flex: 1, minWidth: 0, gap: 4 }}>
            <T size={16} weight="bold" lines={2}>{c.name}</T>{!!c.description && <T size={12} color={theme.muted} lines={2} style={{ lineHeight: 17 }}>{c.description}</T>}
          </View><I name="play-outline" color={theme.muted} size={20} />
        </Click>)}
      </View></View>}
    ListEmptyComponent={empty} ListFooterComponent={footer}
    onEndReached={load} onEndReachedThreshold={.3} showsVerticalScrollIndicator={false}
    refreshControl={refreshControl} />;
}
