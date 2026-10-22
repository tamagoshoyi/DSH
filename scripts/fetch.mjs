// scripts/fetch.mjs — 用 Node 的 TLS 栈下载文件（本机 schannel 被禁用，curl / IWR 不可用）
//
// 用法：node scripts/fetch.mjs <url> <输出路径>
// 特性：自动跟随 3xx 跳转、显示进度、失败时非零退出。

import https from 'node:https';
import { createWriteStream } from 'node:fs';
import { mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';

const [url, out] = process.argv.slice(2);
if (!url || !out) {
  console.error('用法: node scripts/fetch.mjs <url> <输出路径>');
  process.exit(2);
}

const MAX_REDIRECTS = 5;
const UA = 'dsh-workspace-fetch/1.0';

function download(target, dest, redirectsLeft) {
  return new Promise((resolve, reject) => {
    const req = https.get(target, { headers: { 'User-Agent': UA }, timeout: 30000 }, (res) => {
      const { statusCode, headers } = res;

      if (statusCode >= 300 && statusCode < 400 && headers.location) {
        res.resume();
        if (redirectsLeft <= 0) return reject(new Error('跳转次数过多'));
        const next = new URL(headers.location, target).toString();
        return resolve(download(next, dest, redirectsLeft - 1));
      }

      if (statusCode !== 200) {
        res.resume();
        return reject(new Error(`HTTP ${statusCode} ${target}`));
      }

      const total = Number(headers['content-length'] || 0);
      let received = 0;
      let lastPct = -1;

      const file = createWriteStream(dest);
      res.on('data', (chunk) => {
        received += chunk.length;
        if (total) {
          const pct = Math.floor((received / total) * 100);
          if (pct >= lastPct + 10) {
            lastPct = pct - (pct % 10);
            process.stdout.write(`\r${pct}%  ${(received / 1048576).toFixed(1)} MiB`);
          }
        }
      });
      res.pipe(file);
      file.on('finish', () => {
        file.close(() => {
          process.stdout.write(`\r完成 ${(received / 1048576).toFixed(1)} MiB\n`);
          resolve();
        });
      });
      file.on('error', reject);
      res.on('error', reject);
    });
    req.on('timeout', () => { req.destroy(new Error('连接超时')); });
    req.on('error', reject);
  });
}

try {
  await mkdir(dirname(out), { recursive: true });
  await download(url, out, MAX_REDIRECTS);
  console.log(`已保存: ${out}`);
} catch (err) {
  console.error(`下载失败: ${err.message}`);
  process.exit(1);
}
