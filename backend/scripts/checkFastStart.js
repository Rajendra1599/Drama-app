/**
 * FastStart MP4 Box Order Checker
 * Analyzes whether an MP4 file has FastStart (+faststart) enabled
 * (moov atom before mdat atom for sub-500ms instant streaming)
 *
 * Usage:
 *   node backend/scripts/checkFastStart.js <filePathOrUrl>
 */

const fs = require('fs');
const https = require('https');
const http = require('http');

function parseMp4Boxes(buffer) {
  let offset = 0;
  const boxes = [];
  while (offset < buffer.length - 8) {
    const size = buffer.readUInt32BE(offset);
    const type = buffer.toString('ascii', offset + 4, offset + 8);
    boxes.push({ type, size, offset });
    if (size === 0 || size === 1) break; // Extended or unbounded
    offset += size;
  }
  return boxes;
}

function analyzeBoxes(boxes) {
  console.log('\n📦 MP4 Atom Structure:');
  boxes.forEach((b, i) => {
    console.log(`   ${i + 1}. [${b.type}] offset: ${b.offset} bytes, size: ${(b.size / 1024).toFixed(1)} KB`);
  });

  const moov = boxes.find(b => b.type === 'moov');
  const mdat = boxes.find(b => b.type === 'mdat');

  console.log('\n📊 Verdict:');
  if (moov && mdat) {
    if (moov.offset < mdat.offset) {
      console.log('   ✅ FASTSTART ENABLED: "moov" is at offset ' + moov.offset + ' (BEFORE "mdat" at ' + mdat.offset + ').');
      console.log('   ⚡ Video player will start playback INSTANTLY without downloading the entire file.');
    } else {
      console.log('   ❌ NOT FASTSTART: "mdat" is at offset ' + mdat.offset + ' (BEFORE "moov" at ' + moov.offset + ').');
      console.log('   ⚠️ Player must download or seek to end of file to read metadata before decoding.');
      console.log('   💡 Run: ffmpeg -i input.mp4 -c copy -movflags +faststart output.mp4');
    }
  } else if (!moov && mdat) {
    console.log('   ❌ NOT FASTSTART: "mdat" found at offset ' + mdat.offset + ', but "moov" was not found in initial bytes.');
    console.log('   ⚠️ "moov" is located at the tail of the file. Player has to make extra network roundtrips to read metadata.');
    console.log('   💡 Run: ffmpeg -i input.mp4 -c copy -movflags +faststart output.mp4');
  } else if (moov && !mdat) {
    console.log('   ✅ "moov" found at offset ' + moov.offset + ' at front of file.');
  } else {
    console.log('   ⚠️ Could not determine box order from given buffer.');
  }
}

async function main() {
  const target = process.argv[2] || 'test_ep1_faststart.mp4';
  console.log(`🔍 Inspecting MP4 FastStart for: ${target}`);

  if (target.startsWith('http://') || target.startsWith('https://')) {
    const client = target.startsWith('https://') ? https : http;
    const req = client.get(target, { headers: { Range: 'bytes=0-131071' } }, (res) => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        const buf = Buffer.concat(chunks);
        const boxes = parseMp4Boxes(buf);
        analyzeBoxes(boxes);
      });
    });
    req.on('error', err => console.error('Network error:', err.message));
  } else {
    if (!fs.existsSync(target)) {
      console.error(`File not found: ${target}`);
      process.exit(1);
    }
    const fd = fs.openSync(target, 'r');
    const buf = Buffer.alloc(131072);
    const bytesRead = fs.readSync(fd, buf, 0, 131072, 0);
    fs.closeSync(fd);
    const boxes = parseMp4Boxes(buf.slice(0, bytesRead));
    analyzeBoxes(boxes);
  }
}

main();
