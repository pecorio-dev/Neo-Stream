import React, { useMemo } from 'react';
import { RefreshControl, ScrollView, View } from 'react-native';
import { useApp } from '../lib/store';
import { explore } from '../lib/navigation';
import { homeSessions } from '../lib/resume';
import { genreOptions } from '../lib/genres';
import type { Kind } from '../lib/types';
import { Hero } from '../components/Hero';
import { PhoneReelHome } from '../components/phone/PhoneReel';
import { TvHome } from '../components/tv/TvHome';
import { Poster, ResumeCard } from '../components/Cards';
import { Footer, plural } from '../components/Browse';
import { Button, Chip, Empty, PageHeading, row, SectionHeader, T, useLayout } from '../components/UI';

const kinds: Kind[] = ['Film', 'Série', 'Animé'];
function Shelf({ title, action, onPress, children }: { title: string; action: string; onPress: () => void; children: React.ReactNode }) {
  const { pad, gap, compact, mobile } = useLayout();
  return <View style={{ marginTop: compact ? 22 : 30 }}>
    <View style={{ paddingHorizontal: pad }}><SectionHeader title={title} action={action} onPress={onPress} /></View>
    <ScrollView horizontal showsHorizontalScrollIndicator={!mobile} contentContainerStyle={{ paddingHorizontal: pad, paddingBottom: 4, gap }}>
      {children}
    </ScrollView>
  </View>;
}

export default function Home() {
  const { tv, phone } = useApp();
  if (tv) return <TvHome />;
  if (phone) return <PhoneReelHome />;
  return <DesktopHome />;
}

function DesktopHome() {
  const { theme, items, history, open, refresh, refreshing, serviceError } = useApp();
  const { pad, compact, cols, shelfWidth, inner, gap } = useLayout();
  const [last, ...others] = homeSessions(history);
  const lead = last?.item ?? items[0];
  const sessionWidth = compact ? Math.min(286, inner * .79) : Math.floor((inner - 2 * gap) / 3);
  const genres = useMemo(() => genreOptions(items), [items]);
  return <ScrollView testID="home-screen" style={{ flex: 1, backgroundColor: theme.bg }} showsVerticalScrollIndicator={false}
    refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={theme.accent} />}>
    <View style={{ paddingHorizontal: pad }}>
       <PageHeading title={last ? 'Reprendre la lecture' : 'À découvrir'} />
       {lead ? <Hero item={lead} entry={last?.entry} /> : <Empty title="Aucun titre disponible" description="Actualisez le catalogue pour retrouver les œuvres disponibles." action="Actualiser" onPress={refresh} />}
      {!!serviceError && <View style={[row, { marginTop: 10, gap: 10, flexWrap: 'wrap' }]}><T size={12} color={theme.muted}>{serviceError}</T><Button small variant="ghost" label="Actualiser" icon="refresh" onPress={refresh} /></View>}
    </View>
    {others.length > 0 && <Shelf title="Autres séances" action="Historique" onPress={() => open({ type: 'collection', section: 'history' })}>
      {others.slice(0, 8).map(v => <ResumeCard key={v.item.id} {...v} width={sessionWidth} />)}
    </Shelf>}
    {kinds.map(kind => {
      const titles = items.filter(m => m.kind === kind && m.id !== lead?.id).slice(0, Math.max(cols, 5));
      return titles.length > 0 && <Shelf key={kind} title={plural(kind)} action={kind === 'Série' ? 'Toutes les séries' : `Tous les ${plural(kind).toLocaleLowerCase('fr')}`} onPress={() => explore(kind)}>
        {titles.map(item => <Poster key={item.id} item={item} width={shelfWidth} />)}
      </Shelf>;
    })}
    {genres.length > 0 && <View style={{ paddingHorizontal: pad, marginTop: 30 }}><SectionHeader title="Par genre" />
      <View style={[row, { gap: 8, flexWrap: 'wrap' }]}>{genres.map(g => <Chip key={g} label={g} onPress={() => explore('Tout', g)} />)}</View>
    </View>}
    <Footer />
  </ScrollView>;
}
