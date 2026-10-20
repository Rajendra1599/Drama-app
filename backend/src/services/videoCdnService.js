/**
 * MicroDrama OTT - Scalable Cloudinary CDN & Adaptive Video Streaming Service
 * 
 * Scalability Architecture:
 * - 100% Zero-Server Media Bandwidth: All video chunks & images are served directly by Cloudinary CDN edge nodes
 * - Node.js Express server only handles lightweight authorization metadata (<1KB per request)
 * - Mobile Vertical 9:16 Optimization (ar_9:16, c_fill, w_720, q_auto:good, f_auto)
 * - Cloudinary HLS (HTTP Live Streaming) Adaptive Bitrate Manifests (.m3u8)
 * - Direct Client-to-Cloudinary Signed Uploads (bypasses Node.js for heavy video uploads)
 * - Dynamic Video Poster & Thumbnail Extraction at second 0 (so_0, webp/jpg)
 * - Cryptographically signed, time-limited playback tokens
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const cloudinary = require('cloudinary').v2;

const CLOUD_NAME = process.env.CLOUDINARY_CLOUD_NAME || 'microdrama-ott';
const API_KEY = process.env.CLOUDINARY_API_KEY || '';
const API_SECRET = process.env.CLOUDINARY_API_SECRET || '';
const CONTENT_ENCRYPTION_KEY = process.env.CONTENT_ENCRYPTION_KEY || 'microdrama_aes_256_content_key_32bytes!';
const VIDEO_CDN_BASE_URL = process.env.VIDEO_CDN_BASE_URL || `https://res.cloudinary.com/${CLOUD_NAME}/video/upload/`;

// AWS CloudFront Signed URL Configuration
const CLOUDFRONT_KEY_PAIR_ID = process.env.CLOUDFRONT_KEY_PAIR_ID || 'K14SZHS1YOCZG1';
let cloudFrontPrivateKey = null;

function getCloudFrontPrivateKey() {
  if (cloudFrontPrivateKey) return cloudFrontPrivateKey;
  try {
    const candidatePaths = [
      process.env.CLOUDFRONT_PRIVATE_KEY_PATH,
      path.join(__dirname, '../../keys/private_key.pem'),
      path.join(__dirname, '../keys/private_key.pem'),
      path.join(process.cwd(), 'keys/private_key.pem'),
      path.join(process.cwd(), 'backend/keys/private_key.pem')
    ].filter(Boolean);

    for (const cp of candidatePaths) {
      const resolved = path.isAbsolute(cp) ? cp : path.resolve(process.cwd(), cp);
      if (fs.existsSync(resolved)) {
        cloudFrontPrivateKey = fs.readFileSync(resolved, 'utf8');
        console.log(`[CloudFront] Private key loaded from: ${resolved}`);
        return cloudFrontPrivateKey;
      }
    }
  } catch (err) {
    console.error('[CloudFront] Error loading private key:', err.message);
  }
  return null;
}

// Initialize Cloudinary SDK
if (CLOUD_NAME && API_KEY && API_SECRET) {
  cloudinary.config({
    cloud_name: CLOUD_NAME,
    api_key: API_KEY,
    api_secret: API_SECRET,
    secure: true
  });
  console.log(`[Cloudinary] CDN initialized for cloud: ${CLOUD_NAME}`);
}

class VideoCdnService {
  /**
   * Cryptographically signs AWS CloudFront URLs using RSA-SHA1 with canned policy.
   * Resolves HTTP 403 MissingKey errors for restricted CloudFront distributions.
   */
  signCloudFrontUrl(videoUrl, expiresInSeconds = 86400) {
    if (!videoUrl || typeof videoUrl !== 'string') return videoUrl;
    const url = videoUrl.trim();
    if (!url.includes('.cloudfront.net')) {
      return url;
    }
    // Prevent double signing
    if (url.includes('Key-Pair-Id=') && url.includes('Signature=')) {
      return url;
    }

    const privateKey = getCloudFrontPrivateKey();
    if (!privateKey) {
      console.warn('[CloudFront] Private key unavailable for signing:', url);
      return url;
    }

    try {
      const [baseUrl] = url.split('?');
      const expires = Math.floor(Date.now() / 1000) + expiresInSeconds;
      const cannedPolicy = JSON.stringify({
        Statement: [
          {
            Resource: baseUrl,
            Condition: {
              DateLessThan: {
                'AWS:EpochTime': expires
              }
            }
          }
        ]
      });

      const signer = crypto.createSign('RSA-SHA1');
      signer.update(cannedPolicy);
      const signature = signer.sign(privateKey, 'base64')
        .replace(/\+/g, '-')
        .replace(/=/g, '_')
        .replace(/\//g, '~');

      return `${baseUrl}?Expires=${expires}&Signature=${signature}&Key-Pair-Id=${CLOUDFRONT_KEY_PAIR_ID}`;
    } catch (e) {
      console.error('[CloudFront] Signing error:', e.message);
      return url;
    }
  }

  /**
   * Generates a Cloudinary adaptive bitrate HLS (.m3u8) streaming URL for 9:16 mobile vertical video.
   * Enables automatic resolution switching (1080p, 720p, 480p) based on client mobile network bandwidth.
   */
  getCloudinaryHlsStreamUrl(publicIdOrUrl) {
    if (!publicIdOrUrl) return '';

    // Direct stream from any custom CDN (BunnyCDN, CloudFront, S3, etc.)
    if (publicIdOrUrl.startsWith('http') && !publicIdOrUrl.includes('res.cloudinary.com')) {
      return publicIdOrUrl;
    }

    if (publicIdOrUrl.includes('res.cloudinary.com')) {
      return publicIdOrUrl
        .replace(/\/video\/upload\/[^/]*\//, '/video/upload/sp_auto,ar_9:16,c_fill,w_720,q_auto/')
        .replace(/\.(mp4|mov|mkv)$/i, '.m3u8');
    }

    const publicId = publicIdOrUrl.replace(/\.(mp4|m3u8)$/i, '');
    return `https://res.cloudinary.com/${CLOUD_NAME}/video/upload/sp_auto,ar_9:16,c_fill,w_720,q_auto/${publicId}.m3u8`;
  }

  /**
   * Generates an optimized 9:16 progressive MP4 URL with auto-compression and format negotiation
   */
  getCloudinaryOptimizedMp4Url(publicIdOrUrl) {
    if (!publicIdOrUrl) return '';

    // If already a full URL from any custom CDN / provider, deliver directly
    if (publicIdOrUrl.startsWith('http') && !publicIdOrUrl.includes('res.cloudinary.com')) {
      return publicIdOrUrl;
    }

    if (publicIdOrUrl.includes('res.cloudinary.com')) {
      // Automatic adaptive bitrate, compression & format optimization based on mobile network
      let url = publicIdOrUrl;
      if (!url.includes('q_auto')) {
        url = url.replace(
          '/video/upload/',
          '/video/upload/q_auto:eco,f_auto,vc_auto,w_720/'
        );
      }
      return url;
    }

    if (!publicIdOrUrl.startsWith('http')) {
      const publicId = publicIdOrUrl.replace(/\.mp4$/i, '');
      return `https://res.cloudinary.com/${CLOUD_NAME}/video/upload/q_auto:eco,f_auto,vc_auto,w_720/${publicId}.mp4`;
    }

    return publicIdOrUrl;
  }

  /**
   * Universal Video URL Optimizer for Admin Portal & API Uploads.
   * Ensures ANY video uploaded to the website automatically streams
   * with adaptive network-aware compression.
   */
  optimizeVideoUrlForStreaming(rawUrl) {
    if (!rawUrl || typeof rawUrl !== 'string') return '';
    let url = rawUrl.trim();

    // 1. AWS CloudFront Fast Edge CDN Delivery
    if (url.includes('cloudfront.net') || url.includes('.amazonaws.com')) {
      if (url.startsWith('http://')) {
        url = url.replace('http://', 'https://');
      }
      return url;
    }

    // 2. Cloudinary Dynamic Quality & Transcoding
    if (url.includes('res.cloudinary.com')) {
      // Normalize /upload/ to /video/upload/
      if (url.includes('/upload/') && !url.includes('/video/upload/')) {
        url = url.replace('/upload/', '/video/upload/');
      }
      // Inject q_auto:eco, f_auto, vc_auto, w_720 for instant mobile streaming
      if (!url.includes('q_auto')) {
        url = url.replace('/video/upload/', '/video/upload/q_auto:eco,f_auto,vc_auto,w_720/');
      }
      return url;
    }

    // 3. ImageKit Dynamic Transcoding & Edge CDN Caching
    if (url.includes('ik.imagekit.io')) {
      if (!url.includes('/tr:')) {
        url = url.replace(/(https?:\/\/ik\.imagekit\.io\/[^\/]+)\/(.*)/, '$1/tr:q-60,w-720,f-auto/$2');
      }
      return url;
    }

    return url;
  }

  /**
   * Generates a fast 9:16 poster thumbnail extracted directly from the video keyframe at 0 seconds.
   */
  getCloudinaryThumbnailFromVideo(videoUrlOrId, width = 400, height = 711) {
    if (!videoUrlOrId) return '';

    if (videoUrlOrId.includes('res.cloudinary.com')) {
      return videoUrlOrId
        .replace(/\/video\/upload\/[^/]*\//, `/video/upload/so_0,w_${width},h_${height},c_fill,q_auto,f_auto/`)
        .replace(/\.(mp4|m3u8|mov|mkv)$/i, '.webp');
    }

    if (videoUrlOrId.startsWith('http')) {
      return videoUrlOrId;
    }

    const publicId = videoUrlOrId.replace(/\.(mp4|m3u8|mov|mkv)$/i, '');
    return `https://res.cloudinary.com/${CLOUD_NAME}/video/upload/so_0,w_${width},h_${height},c_fill,q_auto,f_auto/${publicId}.webp`;
  }

  /**
   * Generates responsive image URL with CDN caching and automatic format negotiation (AVIF/WebP)
   */
  getOptimizedImageUrl(publicIdOrUrl, width = 400, height = 600) {
    if (!publicIdOrUrl) return '';

    if (publicIdOrUrl.includes('res.cloudinary.com')) {
      return publicIdOrUrl.replace(
        /\/image\/upload\/[^/]*\//,
        `/image/upload/w_${width},h_${height},c_fill,q_auto,f_auto/`
      );
    }

    if (!publicIdOrUrl.startsWith('http')) {
      return `https://res.cloudinary.com/${CLOUD_NAME}/image/upload/w_${width},h_${height},c_fill,q_auto,f_auto/${publicIdOrUrl}`;
    }

    return publicIdOrUrl;
  }

  /**
   * Generates time-limited signed stream authorization payload.
   * Returns both adaptive HLS (.m3u8) and progressive MP4 streaming URLs.
   */
  generateSignedStreamUrl(seriesId, episodeNumber, userId = 'anon', isVip = false, customVideoUrl = null) {
    const expiresAt = Math.floor(Date.now() / 1000) + (2 * 60 * 60); // 2 hours validity

    const token = crypto
      .createHmac('sha256', CONTENT_ENCRYPTION_KEY)
      .update(`${seriesId}:${episodeNumber}:${userId}:${expiresAt}`)
      .digest('hex');

    // If an explicit or custom CDN/media video URL is provided, stream it directly!
    if (customVideoUrl && typeof customVideoUrl === 'string' && customVideoUrl.startsWith('http')) {
      const finalUrl = customVideoUrl.includes('.cloudfront.net')
        ? this.signCloudFrontUrl(customVideoUrl)
        : customVideoUrl;
      return {
        streamUrl: finalUrl,
        hlsUrl: finalUrl,
        mp4Url: finalUrl,
        expiresAt,
        token
      };
    }

    const publicPath = `microdrama/${seriesId}/ep_${String(episodeNumber).padStart(2, '0')}`;

    // If Cloudinary credentials are mock/default, provide high-availability CDN test streams
    if (CLOUD_NAME === 'microdrama-ott' || CLOUD_NAME.includes('your_cloudinary')) {
      const sampleUrl = episodeNumber <= 5
        ? 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4'
        : 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

      return {
        streamUrl: `${sampleUrl}?token=${token}&exp=${expiresAt}`,
        hlsUrl: `${sampleUrl}?token=${token}&exp=${expiresAt}`,
        mp4Url: `${sampleUrl}?token=${token}&exp=${expiresAt}`,
        expiresAt,
        token
      };
    }

    const cdnBase = VIDEO_CDN_BASE_URL ? (VIDEO_CDN_BASE_URL.endsWith('/') ? VIDEO_CDN_BASE_URL : `${VIDEO_CDN_BASE_URL}/`) : `https://res.cloudinary.com/${CLOUD_NAME}/video/upload/`;
    const isCloudinary = cdnBase.includes('res.cloudinary.com');
    const hlsUrl = isCloudinary
      ? `${cdnBase}sp_auto,ar_9:16,c_fill,w_720,q_auto/${publicPath}.m3u8?token=${token}&exp=${expiresAt}`
      : `${cdnBase}${publicPath}.m3u8`;
    const mp4Url = isCloudinary
      ? `${cdnBase}q_auto:good,f_auto,w_720,c_fill,ar_9:16/${publicPath}.mp4?token=${token}&exp=${expiresAt}`
      : `${cdnBase}${publicPath}.mp4`;

    return {
      streamUrl: hlsUrl,
      hlsUrl,
      mp4Url,
      expiresAt,
      token
    };
  }

  /**
   * Creates direct-to-Cloudinary upload signature.
   * Bypasses Node.js server so heavy video uploads travel directly from client/browser to Cloudinary CDN.
   */
  createUploadSignature(folder = 'microdrama/episodes') {
    const timestamp = Math.round(new Date().getTime() / 1000);
    const paramsToSign = {
      folder,
      timestamp
    };

    if (!API_SECRET) {
      return { timestamp, signature: 'mock_direct_upload_sig', cloudName: CLOUD_NAME, folder };
    }

    const signature = cloudinary.utils.api_sign_request(paramsToSign, API_SECRET);
    return {
      timestamp,
      signature,
      apiKey: API_KEY,
      cloudName: CLOUD_NAME,
      folder,
      uploadUrl: `https://api.cloudinary.com/v1_1/${CLOUD_NAME}/video/upload`
    };
  }
}

module.exports = new VideoCdnService();
