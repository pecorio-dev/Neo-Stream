import identities from '../assets/catalogue/iptv-directory.json' with { type: 'json' };
import { playableSources } from '../components/playback';
import { channels } from './channels';
import type { Channel } from './types';

/** apiBase is the already-normalized API_BASE. Slugs belong to this service only. */
export function initialLiveChannels(apiBase: string): Channel[] {
  if (apiBase !== 'https://neo-stream.eu/api/app.php') {
    return channels.flatMap(channel => {
      const sources = playableSources(channel.sources);
      return sources.length ? [{ ...channel, sources }] : [];
    });
  }
  return identities.map(({ slug, name, category }) => ({
    id: `tv_${slug}`,
    name,
    category: category[0].toUpperCase() + category.slice(1),
    mark: slug.replace(/^\d+-/, '').slice(0, 3).toUpperCase(),
    colors: ['#252a3a', '#161820'],
    description: 'En direct.',
    sources: [],
  }));
}
