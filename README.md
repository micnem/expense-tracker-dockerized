# expense-tracker

Webhook service that receives invoice emails from Google Apps Script, extracts normalized expense fields from PDF attachments or email body text, and returns a parse result. Google Apps Script owns the spreadsheet writes, dedupe checks, and Gmail labeling.

## Stack

- Node 20+ (container uses Node 24)
- Docker and Docker Compose (app, Postgres, Redis)
- TypeScript
- Fastify
- Gemini for structured extraction fallback
- Google Apps Script for Google Sheets writes

## API

### `POST /ingest/email-invoice`

Required header:

```text
x-expense-tracker-secret: <WEBHOOK_SHARED_SECRET>
```

Expected body shape:

```json
{
  "messageId": "...",
  "threadId": "...",
  "subject": "Invoice March 2026",
  "from": "Vendor <billing@vendor.com>",
  "to": "you@company.com",
  "cc": "",
  "bcc": "",
  "replyTo": "",
  "date": "2026-03-31T08:15:00.000Z",
  "plainBody": "Hi, please find attached invoice...",
  "htmlBody": "<html><body><p>Hi, please find attached invoice...</p></body></html>",
  "snippet": "Hi, please find attached invoice...",
  "attachments": [
    {
      "filename": "invoice-123.pdf",
      "contentType": "application/pdf",
      "size": 184233,
      "contentBase64": "JVBERi0xLjQKJ..."
    }
  ]
}
```

Success responses:

- `200` with `{ status: "parsed", dedupeKey, receivedAt, parsedExpense }`
- `202` with `{ status: "review", dedupeKey, receivedAt, reason, extractedDraft }`

The backend no longer writes to Google Sheets directly.

## Running with Docker

The service is containerized. The `Dockerfile` is a multi-stage build on `node:24-slim`: the build stage runs `npm ci` and `tsc`, and the runtime stage installs production dependencies only, copies the compiled `dist/src`, runs as the non-root `node` user, and exposes a `/health` healthcheck.

`compose.yaml` defines three services:

| Service | Image | Purpose |
| --- | --- | --- |
| `app` | built from `Dockerfile` | The webhook service, published on host port `8787` (container port `3000`) |
| `db` | `postgres:17` | Postgres with a persistent `db-data` volume |
| `redis` | `redis:8` | Redis with AOF persistence and a persistent `redis-data` volume |

`app` waits for `db` and `redis` to be healthy before starting. Compose passes `DATABASE_URL` and `REDIS_URL` to `app`, but the service code does not read them yet.

### Setup

1. Create a `.env` file in the project root (there is no `.env.example` yet). The service reads these variables:

   ```text
   PORT=3000
   WEBHOOK_SHARED_SECRET=
   GOOGLE_SHEET_ID=
   GOOGLE_SERVICE_ACCOUNT_JSON=
   GEMINI_API_KEY=
   GEMINI_MODEL=
   DEFAULT_CURRENCY=
   MIN_CONFIDENCE=
   EXPENSES_TAB_NAME=
   REVIEW_TAB_NAME=
   INGEST_LOG_TAB_NAME=
   ```

   `.env` is excluded from the image by `.dockerignore` and loaded at runtime via `env_file`.

2. Build and start everything:

   ```bash
   docker compose up --build
   ```

3. Check that it is up:

   ```bash
   curl http://localhost:8787/health
   ```

   The webhook is then at `http://localhost:8787/ingest/email-invoice`.

Useful commands:

```bash
docker compose up -d --build   # run in the background
docker compose logs -f app     # follow app logs
docker compose down            # stop (keeps data volumes)
docker compose down -v         # stop and delete Postgres/Redis data
```

To run only the app image on its own:

```bash
docker build -t expense-tracker .
docker run --rm -p 8787:3000 --env-file .env expense-tracker
```

## Local development (without Docker)

Requires Node 20+.

```bash
npm install
npm run dev     # tsx watch on src/server.ts
npm test        # vitest
npm run check   # type-check
```

## Apps Script

A complete Apps Script implementation lives at `appscript/invoice-ingest.gs`.

That script:

- calls the webhook
- bootstraps `Expenses`, `Review`, and `IngestLog`
- dedupes by message id and by matching reference-plus-amount signatures
- writes columns `A:E` in `Expenses`, leaving `Total` formula-owned
- marks Gmail threads as processed after `parsed`, `duplicate`, or `review`

## Deployment

The `Dockerfile` produces a self-contained image that can run on any container platform, including scale-to-zero platforms like Cloud Run, since the service no longer needs long-lived Google Sheets credentials. Set the environment variables above on the platform and route traffic to `PORT` (default `3000`). Postgres and Redis from `compose.yaml` are for local use only.
