import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { TosClient } from '@volcengine/tos-sdk';

const accessKeyId = process.env.VITE_TOS_ACCESS_KEY_ID;
const accessKeySecret = process.env.VITE_TOS_SECRET_ACCESS_KEY;
const region = process.env.VITE_TOS_REGION;
const bucket = process.env.VITE_TOS_BUCKET;
const endpoint = process.env.VITE_TOS_ENDPOINT;

const filePath = process.argv[2];
const prefix = process.argv[3] || process.env.TOS_KEY_PREFIX || 'datasets';

if (!filePath) {
  process.stderr.write('Usage: node scripts/upload-to-tos.mjs <file_path> [prefix]\n');
  process.exit(1);
}

if (!accessKeyId || !accessKeySecret || !region || !bucket) {
  process.stderr.write('Missing VITE_TOS_ACCESS_KEY_ID / VITE_TOS_SECRET_ACCESS_KEY / VITE_TOS_REGION / VITE_TOS_BUCKET\n');
  process.exit(1);
}

const expires = Number(process.env.TOS_PRESIGN_EXPIRES || 3600);

const client = new TosClient({
  accessKeyId,
  accessKeySecret,
  region,
  endpoint,
});

const ext = path.extname(filePath);
const base = path.basename(filePath, ext);
const ts = Date.now();
const rand = crypto.randomBytes(4).toString('hex');
const safeBase = base.replace(/[^\w.-]+/g, '_').slice(0, 80) || 'file';
const key = `${prefix}/${ts}_${rand}_${safeBase}${ext}`;

await client.putObject({
  bucket,
  key,
  body: fs.createReadStream(filePath),
});

const url = client.getPreSignedUrl({
  bucket,
  key,
  method: 'GET',
  expires,
});

process.stdout.write(JSON.stringify({ key, url }) + '\n');
