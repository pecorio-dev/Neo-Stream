import { router } from 'expo-router';
import type { Category } from './types';

export function explore(category: Category = 'Tout', genre?: string) {
  router.navigate({ pathname: '/catalogue', params: { category, ...(genre ? { genre } : {}), stamp: String(Date.now()) } });
}

export function searchFor(query: string) {
  router.navigate({ pathname: '/recherche', params: { query, stamp: String(Date.now()) } });
}
