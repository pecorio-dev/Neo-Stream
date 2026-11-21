import type { TrackSelection } from './playerTypes';

type Entry<T> = { key: string; label: string; value: T };
let nextId = 0;

/** One scope per decoder AND setting. Only opaque IDs leave the adapter, never
 * a manifest URL or a track-array index that could refer to another source. */
export function createChoiceScope<T>() {
  let ids = new Map<string, string>();
  let bindings = new Map<string, T>();
  let snapshot: TrackSelection | undefined;
  return {
    update(entries: Entry<T>[], selectedKey: string | null): TrackSelection | undefined {
      const nextIds = new Map<string, string>(), nextBindings = new Map<string, T>();
      const options: TrackSelection['options'] = [];
      for (const { key, label, value } of entries) {
        if (!key || !label || nextIds.has(key)) continue;
        const id = ids.get(key) ?? `track-${++nextId}`;
        nextIds.set(key, id); nextBindings.set(id, value); options.push({ id, label });
      }
      ids = nextIds; bindings = nextBindings;
      const selected = selectedKey === null ? null : ids.get(selectedKey) ?? null;
      if (!options.length) snapshot = undefined;
      else if (!snapshot || snapshot.selected !== selected || snapshot.options.length !== options.length ||
        options.some(({ id, label }, i) => snapshot!.options[i].id !== id || snapshot!.options[i].label !== label)) {
        snapshot = { options, selected };
      }
      return snapshot;
    },
    choose(id: string, apply: (value: T) => void): boolean {
      if (!bindings.has(id)) return false;
      apply(bindings.get(id)!); // null can itself be a valid binding (Auto/Off).
      return true;
    },
    clear() { ids.clear(); bindings.clear(); snapshot = undefined; },
  };
}
