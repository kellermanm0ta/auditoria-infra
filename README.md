# AuditorIA — Infraestrutura

Docker Compose + Nginx que orquestram a stack completa do **AuditorIA**, e também
servem somente o banco para desenvolvimento local.

| Serviço   | Imagem / Build                          | Papel                                    |
|-----------|-----------------------------------------|------------------------------------------|
| `postgres` | `postgres:15` + `scripts/init.sql` (seed) | Banco de dados                        |
| `backend` | build de `../backend` (`backend/Dockerfile`) | API REST (FastAPI + Uvicorn, porta 8000) |
| `nextjs`  | build de `../frontend` (`frontend/Dockerfile`) | Web app (Next.js, porta 3000)     |
| `nginx`   | `nginx:alpine` (proxy)                  | Entrada única (porta 80), proxy `/api/*` |

Todo o setup do banco (Compose + seed) que antes ficava no backend agora vive aqui.
O `backend/` não tem mais `docker-compose.yml` nem `scripts/`.

## Repositórios dependentes

Este projeto orquestra os demais serviços do AuditorIA (builda as imagens a partir dos
seus Dockerfiles e os conecta na rede):

| Projeto | Repositório |
|---|---|
| API REST (backend) | `git@github.com:kellermanm0ta/auditor-ia-backend.git` |
| Web app (frontend) | `git@github.com:kellermanm0ta/auditor-ia.git` |

Clone-os no mesmo nível deste repo para a stack subir (o compose usa `../backend` e `../frontend`).

## Pré-requisitos

- **Docker** 24+
- **Docker Compose** v2.23+ (plugin `docker compose`, não `docker-compose`)

## Configuração inicial

```bash
cp .env.example .env
```

O Compose lê o `.env` do `infra/`. Se algo for omitido, usa defaults sensíveis.

---

## Modo 1 — Desenvolvimento local (somente banco de dados)

Sobe **apenas** o PostgreSQL. Backend e frontend rodam na sua máquina (sem Docker),
com hot-reload — ideal para desenvolvimento.

```bash
cd infra
docker compose up -d postgres
# container: auditoria-postgres — porta 5432 exposta no host
```

Com o postgres de pé, rode a API e o web app em terminais separados:

```bash
# backend (FastAPI) — a partir de backend/
cd ../backend
source .venv/bin/activate
uvicorn app.main:app --reload      # http://localhost:8000/docs

# frontend (Next.js) — a partir de ../frontend
cd ../frontend
npm install
npm run dev                        # http://localhost:3000
```

> O `next.config.ts` do frontend tem proxy de dev `/api/*` → `http://localhost:8000/api/*`.
> O postgres local é alcançado em `localhost:5432` (variaveis do `backend/.env`).

### Sync de credenciais

O `backend/.env` (usado pelo `uvicorn` local) e o `infra/.env` (usado pelo postgres) precisam
coincidir em `POSTGRES_USER`, `POSTGRES_PASSWORD` e `POSTGRES_DB`. Defaults de ambos:
`postgres` / `postgres` / `auditoria`.

---

## 2 — Stack completa (produção)

Sobe todos os serviços (postgres + api + web + nginx) — reproduz o ambiente de produção:

```bash
cd infra
docker compose up -d --build
```

Acessos:

| Recurso | URL |
|-------------|---------|
| Web app | http://localhost/ |
| API (Swagger) | http://localhost/docs |
| Health check | http://localhost/health |

> O Nginx é a única porta exposta. Backend e frontend ficam isolados na rede `app-network`.

### Rotação

```bash
docker compose up -d            # sobe usando imagens já construídas
docker compose up -d --build    # sobe reconstruindo as imagens
docker compose down             # derruba (mantém o volume do banco)
docker compose down -v          # derruba e apaga o volume do banco (perde dados/seed)
docker compose logs -f backend  # acompanhar logs
```

---

## Estrutura

```
infra/
├── docker-compose.yml   # orquestração (postgres, backend, nextjs, nginx)
├── nginx.conf           # proxy: / -> nextjs, /api/* -> backend, /_next/static -> nextjs
├── scripts/
│   └── init.sql         # seed do banco (executado na 1ª subida do postgres)
├── .env                 # variáveis locais (não versionar)
├── .env.example         # modelo versionado
└── README.md
backend/
└── Dockerfile           # imagem da API (contexto = backend/)
frontend/
└── Dockerfile           # imagem do Next.js (contexto = frontend/)
```

### Dockerfiles na raiz dos projetos

Cada serviço é self-contained: `docker build backend/` e `docker build frontend/` geram as
imagens diretamente. O compose usa `build.context` apontando para cada pasta e o Dockerfile
padrão (`Dockerfile`) de cada uma.

## Fluxo da API (fora vs. dentro do container)

| Ambiente | `POSTGRES_HOST` | Por quê |
|--------------|-----------------|-------|
| Dev (sem Docker) | `localhost` (do `backend/.env`) | postgres roda na própria máquina |
| Docker | `postgres` (injetado no compose) | postgres é um serviço da rede |

A URL fica em `backend/app/core/settings.py` — configuração via **env**, sem valores cravados.

## Configuração (`infra/.env`)

| Variável | Padrão | Descrição |
|----------|--------|------|
| `POSTGRES_USER` | `postgres` | Usuário do banco |
| `POSTGRES_PASSWORD` | `postgres` | Senha do banco |
| `POSTGRES_DB` | `auditoria` | Nome do banco |
| `POSTGRES_HOST` | `postgres` | Host do banco visto de dentro da rede docker |
| `POSTGRES_PORT` | `5432` | Porta do postgres exposta no host |
| `DEBUG` | `true` | Debug do backend |
| `NGINX_PORT` | `80` | Porta do nginx no host |
| `BACKEND_URL` | `http://backend:8000` | Destino do proxy `/api/*` |

## Rotas do Nginx

| Location | Destino | Notas |
|--------------|-----------|------|
| `/_next/static` | `nextjs:3000` | Cache `immutable`, expiry 1y |
| `/api/*` | `$BACKEND_URL` | Proxy para a API (backend:8000) |
| `/docs`, `/redoc`, `/openapi.json` | `$BACKEND_URL` | Documentação da API |
| `/` | `nextjs:3000` | Web app |

## Solução de problemas

- **`Conflict. The container name "/auditoria-postgres" is already in use`**: container criado
  com o compose antigo (`backend/docker-compose.yml`). Remova: `docker rm -f auditoria-postgres`
  e suba novamente pelo `infra/`.
- **Seed não é aplicado em banco já criado**: `init.sql` só roda na 1ª criação do volume. Reset:
  `docker compose down -v && docker compose up -d postgres`.