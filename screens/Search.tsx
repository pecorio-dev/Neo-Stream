import React, { useEffect, useMemo, useRef, useState } from "react";
import { FlatList, RefreshControl, View } from "react-native";
import { useLocalSearchParams } from 'expo-router';
import { useApp } from "../lib/store";
import { apiSearch, hasService } from "../lib/api";
import { createSearchSession, type SearchResult } from "../lib/catalogueLookup";
import { Category } from "../lib/types";
import {
  Chip,
  Click,
  Empty,
  I,
  PageHeading,
  row,
  T,
} from "../components/UI";
import { IndexTitle, useIndexLayout } from '../components/TitleIndex';
import { Footer } from '../components/Browse';
import { SearchConsole } from '../components/SearchConsole';
import { PhoneFooter, PhoneHeading } from '../components/phone/PhoneHome';
export const normalize = (s: string) =>
  s
    .toLocaleLowerCase("fr")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .trim();
const popular = ["Dune", "Shōgun", "Interstellar", "Jujutsu Kaisen"];
const searchTypes = { Tout: "all", Film: "film", Série: "serie", Animé: "anime" } as const;
export default function Search() {
  const { stamp, query } = useLocalSearchParams<{ stamp?: string; query?: string }>();
  return (
    <SearchGrid
      key={JSON.stringify([stamp, query])}
      initialQuery={query || ""}
    />
  );
}
function SearchGrid({ initialQuery }: { initialQuery: string }) {
  const {
    items,
    theme,
    searches,
    addSearch,
    removeSearch,
    open,
    refresh,
    refreshing,
    loadMore,
    hasMoreCatalogue,
  } = useApp();
  const { pad, columns, compact, gap, cellWidth, phone, tv } = useIndexLayout();
  const [query, setQuery] = useState(initialQuery);
  const [type, setType] = useState<Category>("Tout");
  const [limit, setLimit] = useState(12);
  const q = normalize(query);
  const term = query.trim();
  const searching = term !== "";
  const remote = searching && hasService;
  const [revision, setRevision] = useState(0);
  const searchKey = useMemo(() => ({ term, type, revision }), [term, type, revision]);
  const [response, setResponse] = useState<{ key: typeof searchKey; result: SearchResult } | null>(null);
  const searchSession = useRef<{ key: typeof searchKey; load: () => Promise<void> } | null>(null);
  useEffect(() => {
    if (!remote) return;
    const session = createSearchSession(
      (cursor) => apiSearch(searchKey.term, searchTypes[searchKey.type], cursor),
      (result) => setResponse({ key: searchKey, result }),
    );
    const timer = setTimeout(() => {
      searchSession.current = { key: searchKey, load: session.load };
      void session.load();
    }, 300);
    return () => {
      clearTimeout(timer);
      session.stop();
      if (searchSession.current?.key === searchKey) searchSession.current = null;
    };
  }, [remote, searchKey]);
  const result = remote && response?.key === searchKey ? response.result : null;
  const localQuery = q || term;
  const localList = useMemo(
    () =>
      items.filter(
        (m) =>
          (type === "Tout" || m.kind === type) &&
          (!localQuery ||
            [
              m.title,
              m.genre,
              m.kind,
              String(m.year),
              ...(m.cast || []),
              m.director || "",
            ].some((v) => (q ? normalize(v) : v).includes(localQuery))),
      ),
    [items, type, q, localQuery],
  );
  const fallback = searching && (!remote || (result?.error === true && result.items.length === 0));
  const list = remote && !fallback ? result?.items ?? [] : localList;
  const pending = remote && (!result || result.pending);
  const choose = (text: string) => {
    setQuery(text);
    addSearch(text);
    setLimit(12);
  };
  const load = () => {
    if (remote && !fallback) {
      if (result?.nextCursor && !pending && !result.error && searchSession.current?.key === searchKey)
        void searchSession.current.load();
    } else if (limit < list.length) setLimit((n) => n + 12);
    else if (!searching && hasMoreCatalogue) void loadMore("catalogue");
  };
  const retry = () => {
    if (searchSession.current?.key === searchKey) void searchSession.current.load();
  };
  const header = (
    <View style={{ paddingBottom: 16 }}>
      {phone ? <PhoneHeading title="Recherche" trace /> : <PageHeading title="Recherche" />}
      <SearchConsole query={query} scope={type} onSubmit={() => addSearch(query)}
        onChange={s => { setQuery(s); setLimit(12); }} onScope={c => { setType(c); setLimit(12); }} />
      {!searching && (
        <View style={{ gap: 10, marginTop: 20 }}>
          {searches.length > 0 && (
            <>
              <View style={[row, { justifyContent: "space-between" }]}>
                <T weight="bold" size={tv ? 18 : 13}>
                  Recherches récentes
                </T>
                <Click label="Tout effacer" onPress={() => removeSearch()} style={{ minHeight: phone || tv ? 48 : 44, justifyContent: 'center' }}>
                  <T size={tv ? 18 : phone ? 14 : 11} color={theme.muted}>
                    Tout effacer
                  </T>
                </Click>
              </View>
              <View style={[row, { flexWrap: "wrap", gap: 8 }]}>
                {searches.slice(0, 6).map((s) => (
                  <View
                    key={s}
                    style={[
                      row,
                      {
                        backgroundColor: theme.surface,
                        borderRadius: 7,
                        borderWidth: 1,
                        borderColor: theme.border,
                        paddingLeft: 10,
                        maxWidth: '100%',
                      },
                    ]}
                  >
                    <Click
                      label={s} onPress={() => choose(s)}
                      style={[row, { gap: 6, minWidth: phone || tv ? 48 : undefined, flexShrink: 1, minHeight: phone || tv ? 48 : 44 }]}
                    >
                      <I name="time-outline" color={theme.faint} size={13} />
                      <T size={tv ? 18 : phone ? 14 : 11} lines={2} style={{ flexShrink: 1 }}>{s}</T>
                    </Click>
                    <Click
                      label={`Supprimer la recherche ${s}`}
                      onPress={() => removeSearch(s)}
                      style={{ minWidth: phone || tv ? 48 : 44, minHeight: phone || tv ? 48 : 44, alignItems: 'center', justifyContent: 'center' }}
                    >
                      <I name="close" size={12} color={theme.faint} />
                    </Click>
                  </View>
                ))}
              </View>
            </>
          )}
          <View
            style={[
              row,
              { flexWrap: "wrap", gap: 8, marginTop: searches.length ? 7 : 0 },
            ]}
          >
            <T size={tv ? 18 : 12} color={theme.muted} weight="semibold">
              Suggestions
            </T>
            {popular.map((s) => tv ? <Click key={s} label={s} onPress={() => choose(s)} style={{ paddingHorizontal: 14, minHeight: 48, justifyContent: 'center', borderBottomWidth: 1, borderColor: theme.border }}><T size={18}>{s}</T></Click> : (
              <Chip
                key={s}
                label={s}
                onPress={() => choose(s)}
              />
            ))}
          </View>
        </View>
      )}
      <View
        style={{
          marginTop: 28,
          paddingTop: 24,
          borderTopWidth: 1,
          borderColor: theme.border,
          gap: 14,
        }}
      >
        <View style={[row, { justifyContent: "space-between" }]}>
          <T
            role="header" weight={phone ? 'bold' : 'display'}
            size={phone ? 22 : compact ? 28 : 34}
            style={{ flexShrink: 1 }}
          >
            {searching ? "Résultats" : "Parcourir les titres"}
          </T>
          <T size={tv ? 18 : 12} color={theme.muted}>
            {pending && !list.length ? "Recherche…" : `${list.length} titre${list.length > 1 ? "s" : ""}`}
          </T>
        </View>
        {fallback && <T size={12} color={theme.muted}>Catalogue distant indisponible. Seuls les titres chargés sur cet appareil sont affichés.</T>}
      </View>
    </View>
  );
  return (
    <FlatList
      testID="search-grid"
      key={columns}
      data={remote && !fallback ? list : list.slice(0, limit)}
      keyExtractor={(m) => m.id}
      numColumns={columns}
      keyboardShouldPersistTaps="handled"
      style={{ backgroundColor: theme.bg }}
      contentContainerStyle={{ paddingHorizontal: pad }}
      columnWrapperStyle={columns > 1 ? { gap, marginBottom: tv ? 14 : 22 } : undefined}
      renderItem={({ item }) => (
        <IndexTitle
          item={item}
          width={cellWidth}
          onPress={() => {
            addSearch(query);
            open({ type: "detail", item });
          }}
        />
      )}
      ListHeaderComponent={header}
      ListEmptyComponent={pending ? null :
        <Empty
          icon="search-outline"
          title={fallback ? "Aucun résultat dans les titres chargés" : "Aucun résultat, pour le moment"}
          description={searching ? `Aucun titre ne correspond à « ${query} » dans cette catégorie.` : "Aucun titre dans cette catégorie."}
          action="Effacer les filtres"
          onPress={() => {
            setQuery("");
            setType("Tout");
          }}
        />
      }
      ListFooterComponent={
        <>
          {pending && <T size={12} color={theme.muted} style={{ paddingBottom: 16 }}>Recherche en cours…</T>}
          {result?.error && <Click onPress={retry} label="Réessayer la recherche" style={phone || tv ? { minHeight: 48, justifyContent: 'center' } : { paddingBottom: 16 }}>
            <T size={13} color={theme.accent}>Recherche interrompue. Réessayer</T>
          </Click>}
          {((result?.nextCursor && !pending && !result.error) || ((phone || tv) && (!remote || fallback) && (limit < list.length || (!searching && hasMoreCatalogue)))) && <Click onPress={load} label="Plus de résultats" style={phone || tv ? { minHeight: 48, justifyContent: 'center' } : { paddingBottom: 16 }}>
            <T size={13} color={theme.accent}>Plus de résultats</T>
          </Click>}
          <View style={{ marginHorizontal: -pad }}>{phone ? <PhoneFooter /> : <Footer />}</View>
        </>
      }
      initialNumToRender={12}
      windowSize={5}
      onEndReached={load}
      onEndReachedThreshold={0.4}
      refreshControl={
        <RefreshControl
          refreshing={remote ? pending : refreshing}
          onRefresh={remote ? () => setRevision((value) => value + 1) : refresh}
          tintColor={theme.accent}
        />
      }
      showsVerticalScrollIndicator={false}
    />
  );
}
