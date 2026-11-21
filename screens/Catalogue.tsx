import React, { useMemo, useState } from 'react';
import { FlatList, RefreshControl, View } from 'react-native';
import { useLocalSearchParams } from 'expo-router';
import { useApp } from '../lib/store';
import type { Category } from '../lib/types';
import { genreOptions, matchesGenre, parseGenres } from '../lib/genres';
import { ControlFrame, Footer, OptionBand, plural } from '../components/Browse';
import { IndexTitle, useIndexLayout } from '../components/TitleIndex';
import { Glass } from '../components/Glass';
import { PhoneFooter, PhoneHeading } from '../components/phone/PhoneHome';
import { Button, Chip, Empty, PageHeading, row, T } from '../components/UI';

const categories: Category[] = ['Tout','Film','Série','Animé'];
const sorts = ['Notre sélection', 'Plus récents', 'De A à Z', 'Mieux notés'] as const;
const anyGenre = 'Tous les genres';
export default function Catalogue() {
  const { category, genre, stamp } = useLocalSearchParams<{ category?: string; genre?: string; stamp?: string }>();
  return <CatalogueGrid key={JSON.stringify([category, genre, stamp])} initial={categories.find(c => c === category) ?? 'Tout'} genre={parseGenres(genre)[0] || anyGenre} />;
}
function CatalogueGrid({ initial, genre: initialGenre }: { initial: Category; genre: string }) {
  const { items, theme, refresh, refreshing, serviceError, loadMore, hasMoreCatalogue } = useApp();
  const { pad, columns, cellWidth, gap, phone, tv } = useIndexLayout();
  const [category, setCategory] = useState(initial);
  const [genre, setGenre] = useState(initialGenre);
  const [sort, setSort] = useState<typeof sorts[number]>(sorts[0]);
  const [filters, setFilters] = useState(initialGenre !== anyGenre);
  const [limit, setLimit] = useState(12);
  const genres = useMemo(() => genreOptions(items, category), [items, category]);
  const switchCategory = (c: Category) => {
    setCategory(c); setLimit(12);
    if (genre !== anyGenre && !items.some(m => (c === 'Tout' || c === m.kind) && matchesGenre(m, genre))) setGenre(anyGenre);
  };
  const filtered = useMemo(() => {
    const list = items.filter(m => (category === 'Tout' || m.kind === category) && (genre === anyGenre || matchesGenre(m, genre)));
    if (sort === 'Plus récents') list.sort((a,b) => b.year - a.year);
    if (sort === 'De A à Z') list.sort((a,b) => a.title.localeCompare(b.title, 'fr'));
    const rating = (s: string) => parseFloat(s.replace(',', '.')) || 0;
    if (sort === 'Mieux notés') list.sort((a,b) => rating(b.rating) - rating(a.rating));
    return list;
  }, [category, genre, items, sort]);
  const load = () => {
    if (limit < filtered.length) setLimit(n => n + 12);
    else if (hasMoreCatalogue) void loadMore('catalogue');
  };
  const filterButton = <Button variant={phone ? 'ghost' : 'secondary'} small={!tv} label="Filtres" accessibilityLabel="Filtrer et trier" icon="options-outline" onPress={() => setFilters(v => !v)}
    style={phone || tv ? { minHeight: 48, backgroundColor: theme.surface, borderColor: theme.border, borderRadius: 10 } : undefined} />;
  const selectGenre = (g: string) => { setGenre(g); setLimit(12); };
  const selectSort = (s: typeof sorts[number]) => { setSort(s); setLimit(12); };
  const header = <View style={{ paddingBottom: 16 }}>
    {phone ? <PhoneHeading title="Catalogue" trace action={filterButton} /> : <PageHeading title="Catalogue" action={filterButton} />}
    {phone || tv ? <ControlFrame testID="catalogue-controls">
      <OptionBand name="Types de titres" testID="catalogue-categories" options={categories} value={category} display={plural} onChange={switchCategory} />
      {filters && <><T weight="bold" size={tv ? 19 : 15}>Genre</T>
        <OptionBand name="Genres" testID="genre-filters" options={[anyGenre, ...genres]} value={genre} onChange={selectGenre} />
        <T weight="bold" size={tv ? 19 : 15}>Trier par</T>
        <OptionBand name="Ordre des titres" testID="catalogue-sorts" options={sorts} value={sort} onChange={selectSort} /></>}
    </ControlFrame> : <><View style={[row, { gap: 7, flexWrap: 'wrap' }]}>{categories.map(c => <Chip key={c} label={plural(c)} active={category === c} onPress={() => switchCategory(c)} />)}</View>
    {filters && <Glass style={{ padding: 16, gap: 10, marginTop: 16 }}>
      <T size={15} weight="bold">Genre</T>
      <View testID="genre-filters" style={[row, { flexWrap: 'wrap', gap: 7 }]}>{[anyGenre, ...genres].map(g => <Chip key={g} label={g} active={genre === g} onPress={() => selectGenre(g)} />)}</View>
      <T size={15} weight="bold" style={{ marginTop: 6 }}>Trier par</T>
      <View style={[row, { flexWrap: 'wrap', gap: 7 }]}>{sorts.map(s => <Chip key={s} label={s} active={sort === s} onPress={() => selectSort(s)} />)}</View>
    </Glass>}</>}
    <View style={[row, { justifyContent: 'space-between', gap: 8, marginTop: 22 }]}>
      <T role="header" weight={phone ? 'bold' : 'display'} size={phone ? 22 : 29} style={{ flexShrink: 1 }}>{genre === anyGenre ? category === 'Tout' ? 'Tous les titres' : plural(category) : genre}</T>
      <T size={tv ? 18 : 12} color={theme.muted}>{filtered.length} titre{filtered.length > 1 ? 's' : ''}</T>
    </View>
    {!!serviceError && <T color={theme.muted} size={tv ? 18 : 12} style={{ marginTop: 8 }}>{serviceError}</T>}
  </View>;
  return <FlatList key={columns} testID="catalogue-grid" numColumns={columns} data={filtered.slice(0,limit)} keyExtractor={m => m.id}
    style={{ flex: 1, backgroundColor: theme.bg }} contentContainerStyle={{ paddingHorizontal: pad }} columnWrapperStyle={columns > 1 ? { gap, marginBottom: tv ? 14 : 24 } : undefined}
    renderItem={({ item }) => <IndexTitle item={item} width={cellWidth} />} ListHeaderComponent={header}
    ListEmptyComponent={<Empty title="Aucun titre pour ces filtres" description="Essayez un autre genre ou affichez tout le catalogue." action="Réinitialiser les filtres" onPress={() => { setCategory('Tout'); setGenre(anyGenre); setLimit(12); }} />}
    ListFooterComponent={<View>{(limit < filtered.length || hasMoreCatalogue) && <Button variant="secondary" label="Charger plus de titres" icon="add" onPress={load} style={{ alignSelf: 'center' }} />}<View style={{ marginHorizontal: -pad }}>{phone ? <PhoneFooter /> : <Footer />}</View></View>}
    onEndReached={load} onEndReachedThreshold={.35} initialNumToRender={12} windowSize={6} showsVerticalScrollIndicator={false}
    refreshControl={<RefreshControl refreshing={refreshing} onRefresh={refresh} tintColor={theme.accent} />} />;
}
