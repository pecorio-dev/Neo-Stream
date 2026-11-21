import { buildResume, isEpisodicTitle, progressEpisode } from './resume';
import { useTitleMedia } from './useTitleMedia';
import { useApp } from './store';
import type { Progress, Title } from './types';

/** The lead and the smaller bookmarks must open exactly the same episode. No sources are resolved here. */
export function useSessionAction(item: Title, entry?: Progress, resolveEpisodeList = true) {
  const { open } = useApp();
  const ambiguousAnime = item.kind === 'Animé' && item.episodic === undefined && !!entry && !progressEpisode(entry);
  const { data } = useTitleMedia(item, resolveEpisodeList && !!entry && (ambiguousAnime || (isEpisodicTitle(item) && entry.total > 0 && entry.position / entry.total > 0.9)));
  const playable = data ? { ...item, catalogId: data.id, episodic: item.episodic ?? data.episodic } : item;
  const episodic = isEpisodicTitle(playable);
  const resume = buildResume(entry, { kind: item.kind, episodic, seasons: data?.seasons });
  const needsDetail = episodic && (!resume || resume.needsCatalogue);
  const label = needsDetail ? 'Voir les épisodes' : resume?.buttonLabel ?? 'Regarder';
  const remaining = entry && entry.total > 0 && !needsDetail && !resume?.next && !resume?.restart
    ? Math.ceil((entry.total - entry.position) / 60) : null;
  const a11yLabel = `${label} : ${item.title}${remaining ? `, ${remaining} min restantes` : ''}`;
  return { resume, label, a11yLabel, remaining, play: () => open(needsDetail ? { type: 'detail', item: playable } : {
    type: 'watch', item: playable, ...resume?.target, restart: resume?.restart,
  }) };
}
