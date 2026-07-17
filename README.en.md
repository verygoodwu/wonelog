# Wonelog

Wonelog is a self-hosted blogging platform made of an Astro static site, a Flutter Windows desktop client, and a Flask publishing service.

It is designed for writers who want to keep their Markdown files and media under their own control while still enjoying a desktop publishing workflow.

## Features

- Import, drag, edit, and publish Markdown articles
- Manage titles, summaries, tags, content, and cover images
- Upload article media to a server-side image library
- Edit profile, avatar, about page, footer, cities, links, and projects
- Create, select, publish, restore, and delete snapshots
- Build and deploy the static site over SSH
- Optional GitHub-backed image storage

## Components

- `apps/blog`: Astro static frontend
- `apps/desktop`: Flutter Windows client
- `apps/server`: Flask API and publishing core
- `data`: example and persistent data
- `deploy`: Docker deployment files
- `docs`: architecture, configuration, usage, and security guides

## Development

```bash
# Blog
cd apps/blog
pnpm install
pnpm dev

# Server
cd apps/server
pip install -r requirements.txt
python start_admin.py

# Desktop client
cd apps/desktop
flutter pub get
flutter run -d windows
```

Copy `.env.example` to `.env` before configuring SSH publishing. Never commit private keys, tokens, production snapshots, or personal content.

## License

GNU Affero General Public License v3.0. See [LICENSE](LICENSE).