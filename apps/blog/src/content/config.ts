import { defineCollection, z } from 'astro:content';

const blog = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string().optional().default(''),
    pubDate: z.coerce.date(),
    heroImage: z.string().optional().default(''),
    tags: z.array(z.string()).optional().default([])
  })
});

export const collections = { blog };
