# AuditorIA Infra

Orquestração Docker Compose + Nginx do AuditorIA. Não contém código de aplicação —
orquestra os repos irmãos: `../backend` (API FastAPI) e `../frontend` (Next.js).

## Repos dependentes (devem coexistir como irmãos)

| Projeto | Repositório |
|---|---|
| backend | `git@github.com:kellermanm0ta/auditor-ia-backend.git` |
| frontend | `git@github.com:kellermanm0ta/auditor-ia.git` |

O compose usa `build.context: ../backend` e `../frontend` → clone todos na mesma pasta.
Não há `Dockerfile` aqui; eles vivem na raiz de cada repo irmão (`backend/Dockerfile`,
`frontend/Dockerfile`).

## Comandos

Todos os comandos rodam a partir de `infra/` (o `.env` local vive aqui; `.gitignore` o exclui).

```bash
docker compose up -d postgres        # dev: só o banco (porta 5432 no host)
docker compose up -d --build         # stack completa (produção): postgres+api+web+nginx
docker compose down                  # mantém volume pgdata
docker compose down -v               # apaga volume (perde seed)
docker compose config --quiet        # valida o compose sem subir
docker compose logs -f backend
```

## Gotchas

- `.env` não é versionado (`.gitignore`). Crie com `cp .env.example .env`. Credenciais padrão
  `postgres/postgres/auditoria`; defaults embutidos no compose usam `${VAR:-default}`.
- **Sincronia de credenciais**: `infra/.env` (postgres) e `backend/.env` (uvicorn local) devem
  bater em `POSTGRES_USER/PASSWORD/DB`. Defaults coincidem nos dois.
- **Host do banco diverge**: dev (uvicorn local) usa `localhost:5432`; no Docker é `postgres`
  (serviço de rede). `POSTGRES_HOST` no compose tem default `postgres`.
- **Seed só roda na 1ª criação do volume** (`scripts/init.sql`). Reset completo:
  `docker compose down -v && docker compose up -d postgres`.
- **Imagem não contém `.env`**: Dockerfile do backend copia só `pyproject.toml` + `app/`;
  toda config chega por env vars do compose.
- **Build do backend usa `build.network: host`** no compose — necessário porque o build padrão
  (bridge do BuildKit) falha com SSL ao baixar pacotes PyPI nesta máquina. Não "corrija"
  removendo; é intencional.
- **Conflito de nome de container**: `auditoria-postgres` pode existir de setups antigos
  (compose do backend). Remova: `docker rm -f auditoria-postgres`.
- **Nginx** usa `nginx:alpine` com template `${BACKEND_URL}` via `envsubst` (comando `command:`
  no compose) — não editar `nginx.conf` sem editar o `command`; `/api/*` proxeia para o backend,
  o resto vai para o `nextjs`.

## Rotas do Nginx

| Location | Destino |
|---|---|
| `/_next/static` | `nextjs:3000` (cache 1y) |
| `/api/*` | `$BACKEND_URL` (backend:8000) |
| `/docs`, `/redoc`, `/openapi.json` | `$BACKEND_URL` |
| `/` | `nextjs:3000` |