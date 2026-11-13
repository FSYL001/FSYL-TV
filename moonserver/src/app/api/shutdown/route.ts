import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

// 外壳退出时调用的优雅关闭端点（公开路径 /__shutdown 由 next.config.js 重写而来）。
// 先返回响应，再结束进程；若 1.5 秒内未退出，外壳会 taskkill /T /F。
export async function POST() {
  const response = NextResponse.json({ status: 'shutting-down' });
  setTimeout(() => {
    process.exit(0);
  }, 100);
  return response;
}
