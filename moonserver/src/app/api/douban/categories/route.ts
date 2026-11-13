import { NextResponse } from 'next/server';

import { getCacheTime } from '@/lib/config';
import { DoubanItem, DoubanResult } from '@/lib/types';

interface DoubanCategoryApiResponse {
  total: number;
  items: Array<{
    id: string;
    title: string;
    card_subtitle: string;
    pic: {
      large: string;
      normal: string;
    };
    rating: {
      value: number;
    };
  }>;
}

interface DoubanLegacyResponse {
  subjects: Array<{
    id?: string;
    title: string;
    rate?: string;
    cover?: string;
    url?: string;
  }>;
}

async function fetchJson(
  url: string,
  timeoutMs = 10000
): Promise<unknown> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
          '(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        Referer: 'https://movie.douban.com/',
        Accept: 'application/json, text/plain, */*',
        Origin: 'https://movie.douban.com',
      },
    });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    return await response.json();
  } finally {
    clearTimeout(timeoutId);
  }
}

export const runtime = 'edge';

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);

  const kind = searchParams.get('kind') || 'movie';
  const category = searchParams.get('category');
  const type = searchParams.get('type');
  const pageLimit = parseInt(searchParams.get('limit') || '20');
  const pageStart = parseInt(searchParams.get('start') || '0');

  if (!category || !type) {
    return NextResponse.json(
      { error: '缺少必要参数: category 或 type' },
      { status: 400 }
    );
  }
  if (!['tv', 'movie'].includes(kind)) {
    return NextResponse.json(
      { error: 'kind 参数必须是 tv 或 movie' },
      { status: 400 }
    );
  }
  if (pageLimit < 1 || pageLimit > 100 || pageStart < 0) {
    return NextResponse.json({ error: '分页参数无效' }, { status: 400 });
  }

  // 2026-11: m.douban.com/rexxar is timing out from this network. The legacy
  // movie.douban.com search endpoint still works, so use it first and keep the
  // rexxar endpoint as a fallback.
  const legacyTag =
    kind === 'movie' ? category : category === 'show' ? '综艺' : '热门';
  const legacyType = kind === 'movie' ? 'movie' : 'tv';
  const legacyUrl =
    'https://movie.douban.com/j/search_subjects' +
    `?type=${legacyType}` +
    `&tag=${encodeURIComponent(legacyTag)}` +
    `&sort=recommend&page_limit=${pageLimit}&page_start=${pageStart}`;

  const rexxarUrl =
    `https://m.douban.com/rexxar/api/v2/subject/recent_hot/${kind}` +
    `?start=${pageStart}&limit=${pageLimit}` +
    `&category=${encodeURIComponent(category)}&type=${encodeURIComponent(type)}`;

  const list: DoubanItem[] = [];
  try {
    const legacy = (await fetchJson(legacyUrl, 8000)) as DoubanLegacyResponse;
    for (const item of legacy.subjects ?? []) {
      const id =
        item.id ?? item.url?.match(/subject\/(\d+)/)?.[1] ?? '';
      list.push({
        id,
        title: item.title,
        poster: item.cover ?? '',
        rate: item.rate ?? '',
        year: '',
      });
    }
  } catch {
    try {
      const data = (await fetchJson(rexxarUrl, 10000)) as
        | DoubanCategoryApiResponse
        | null;
      for (const item of data?.items ?? []) {
        list.push({
          id: item.id,
          title: item.title,
          poster: item.pic?.normal || item.pic?.large || '',
          rate: item.rating?.value ? item.rating.value.toFixed(1) : '',
          year: item.card_subtitle?.match(/(\d{4})/)?.[1] || '',
        });
      }
    } catch {
      return NextResponse.json(
        { error: '获取豆瓣数据失败' },
        { status: 500 }
      );
    }
  }

  if (list.length === 0) {
    return NextResponse.json({ error: '获取豆瓣数据失败' }, { status: 500 });
  }

  const cacheTime = await getCacheTime();
  const response: DoubanResult = {
    code: 200,
    message: '获取成功',
    list,
  };
  return NextResponse.json(response, {
    headers: {
      'Cache-Control': `public, max-age=${cacheTime}, s-maxage=${cacheTime}`,
      'CDN-Cache-Control': `public, s-maxage=${cacheTime}`,
      'Vercel-CDN-Cache-Control': `public, s-maxage=${cacheTime}`,
    },
  });
}
