import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

// FSYL TV sidecar 健康检查。不需要认证，供外壳判断页面是否就绪。
export async function GET() {
  return NextResponse.json({
    status: 'ok',
    app: 'fsyltv',
    name: process.env.NEXT_PUBLIC_SITE_NAME || 'FSYL TV',
    uptime: Math.round(process.uptime()),
    time: Date.now(),
  });
}
