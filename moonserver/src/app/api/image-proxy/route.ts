import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

function isPrivateHost(hostname: string): boolean {
  const host = hostname.toLowerCase().replace(/^\[|\]$/g, '');
  if (
    host === 'localhost' ||
    host.endsWith('.local') ||
    host === '::1' ||
    host.startsWith('127.') ||
    host.startsWith('10.') ||
    host.startsWith('192.168.') ||
    host.startsWith('169.254.')
  ) {
    return true;
  }
  const m = /^172\.(\d+)\./.exec(host);
  return m !== null && Number(m[1]) >= 16 && Number(m[1]) <= 31;
}

/**
 * Local image proxy for Douban/TMDB posters. Douban rejects hot-linked images
 * without a movie.douban.com Referer, which is why home-page covers were blank
 * while search results (other hosts) worked.
 */
export async function GET(request: NextRequest) {
  const target = request.nextUrl.searchParams.get('url');
  if (!target) {
    return new NextResponse('missing url', { status: 400 });
  }

  let url: URL;
  try {
    url = new URL(target);
  } catch {
    return new NextResponse('invalid url', { status: 400 });
  }

  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    return new NextResponse('unsupported protocol', { status: 400 });
  }
  if (isPrivateHost(url.hostname)) {
    return new NextResponse('host not allowed', { status: 403 });
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  const headers: Record<string, string> = {
    'User-Agent': UA,
    Accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  };
  if (/(^|\.)doubanio\.com$|(^|\.)douban\.com$/i.test(url.hostname)) {
    headers.Referer = 'https://movie.douban.com/';
  }

  try {
    const response = await fetch(url, {
      headers,
      redirect: 'follow',
      signal: controller.signal,
      cache: 'no-store',
    });
    if (!response.ok) {
      return new NextResponse(null, { status: response.status });
    }
    const contentType = response.headers.get('content-type') || '';
    if (!contentType.toLowerCase().startsWith('image/')) {
      return new NextResponse('not an image', { status: 415 });
    }
    const body = await response.arrayBuffer();
    return new NextResponse(body, {
      status: 200,
      headers: {
        'Content-Type': contentType,
        'Cache-Control': 'public, max-age=86400, stale-while-revalidate=604800',
        'Access-Control-Allow-Origin': '*',
      },
    });
  } catch {
    return new NextResponse('upstream fetch failed', { status: 502 });
  } finally {
    clearTimeout(timer);
  }
}
