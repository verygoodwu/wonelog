import { getCollection } from 'astro:content';
import config from '../content/config.json';

export async function GET({ site }) {
  const siteUrl = (site ?? new URL('https://example.com')).toString().replace(/\/$/, '');
  const posts = (await getCollection('blog')).sort((a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf());
  const items = posts.map((post) => `
    <item>
      <title><![CDATA[${post.data.title}]]></title>
      <link>${siteUrl}/blog/${post.slug}/</link>
      <guid>${siteUrl}/blog/${post.slug}/</guid>
      <pubDate>${post.data.pubDate.toUTCString()}</pubDate>
      <description><![CDATA[${post.data.description ?? ''}]]></description>
    </item>`).join('');

  return new Response(`<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0"><channel>
  <title>${config.siteName ?? 'Wonelog'}</title>
  <link>${siteUrl}</link>
  <description>${config.subtitle ?? '记录、思考与分享'}</description>
  ${items}
</channel></rss>`, { headers: { 'Content-Type': 'application/rss+xml; charset=utf-8' } });
}