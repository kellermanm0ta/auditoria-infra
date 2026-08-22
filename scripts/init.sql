CREATE TABLE IF NOT EXISTS integrations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    icon VARCHAR(50) NOT NULL,
    "desc" TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'disconnected',
    status_label VARCHAR(100) NOT NULL,
    doc_url VARCHAR(500) NOT NULL,
    steps TEXT NOT NULL,
    yaml TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO integrations (name, icon, "desc", status, status_label, doc_url, steps, yaml) VALUES
(
    'GitHub Actions',
    'bi-github',
    'Execute a análise automaticamente em cada push ou pull request.',
    'connected',
    'Conectado',
    '#',
    '["Adicione o token AUDITORIA_TOKEN como secret do repositório.","Crie o arquivo .github/workflows/auditoria.yml:"]',
    $yaml$name: AuditorIA Analysis
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run AuditorIA
        run: |
          curl -s -X POST https://api.auditoria.dev/analyze \
            -H "Authorization: Bearer \${{ secrets.AUDITORIA_TOKEN }}" \
            -H "Content-Type: application/json" \
            -d '{"repo":"\${{ github.repository }}","ref":"\${{ github.ref }}"}'
$yaml$
),
(
    'GitLab CI',
    'bi-gitlab',
    'Integre a análise nos pipelines do GitLab com um job customizado.',
    'disconnected',
    'Desconectado',
    '#',
    '["Configure a variável AUDITORIA_TOKEN no CI/CD Settings do projeto.","Adicione ao seu .gitlab-ci.yml:"]',
    $yaml$auditoria-analysis:
  stage: test
  image: curlimages/curl:latest
  script:
    - curl -s -X POST https://api.auditoria.dev/analyze
        -H "Authorization: Bearer \$AUDITORIA_TOKEN"
        -H "Content-Type: application/json"
        -d '{"repo":"\$CI_PROJECT_PATH","ref":"\$CI_COMMIT_REF_NAME"}'
  only:
    - main
$yaml$
),
(
    'Jenkins',
    'bi-gear-wide-connected',
    'Adicione um stage no seu Jenkinsfile para auditar o código.',
    'disconnected',
    'Desconectado',
    '#',
    '["Instale o plugin de credenciais e adicione AUDITORIA_TOKEN.","Adicione o stage ao seu Jenkinsfile:"]',
    $yaml$stage('AuditorIA') {
  steps {
    script {
      sh """
        curl -s -X POST https://api.auditoria.dev/analyze \\
          -H "Authorization: Bearer \${AUDITORIA_TOKEN}" \\
          -H "Content-Type: application/json" \\
          -d '{"repo":"\${env.GIT_URL}","ref":"\${env.BRANCH_NAME}"}'
      """
    }
  }
}
$yaml$
),
(
    'Webhook Genérico',
    'bi-webhook',
    'Dispere análises de qualquer ferramenta via HTTP POST.',
    'connected',
    'Ativo',
    '#',
    '["Utilize o endpoint abaixo para disparar análises programaticamente:","Exemplo com curl:"]',
    $yaml$curl -X POST https://api.auditoria.dev/webhook \
  -H "Authorization: Bearer SEU_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "repo": "https://github.com/usuario/repositorio",
    "ref": "refs/heads/main",
    "skills": ["seguranca","arquitetura","codesmell"]
  }'
$yaml$
),
(
    'CLI (Linha de Comando)',
    'bi-terminal',
    'Execute análises diretamente do terminal em qualquer ambiente.',
    'connected',
    'Instalado',
    '#',
    '["Instale a CLI com npm:","Execute a análise:"]',
    $yaml$# Instalação
npm install -g auditoria-cli

# Uso
auditoria analyze --repo . --token SEU_TOKEN
$yaml$
),
(
    'Slack',
    'bi-slack',
    'Receba notificações no Slack quando uma análise for concluída.',
    'disconnected',
    'Desconectado',
    '#',
    '["Crie um webhook no Slack (Incoming Webhook).","Configure o webhook nas configurações da plataforma."]',
    $yaml$# Webhook URL (adicione nas configurações)
https://hooks.slack.com/services/T00/B00/xxxxxxxxx
$yaml$
)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS skills (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    icon VARCHAR(50) NOT NULL,
    "desc" TEXT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT false,
    prompt TEXT NOT NULL
);

INSERT INTO skills (id, name, icon, "desc", enabled, prompt) VALUES
(
    'seguranca',
    'Análise de Segurança',
    'bi-shield-check',
    'Identifica vulnerabilidades como SQL injection, XSS, exposição de secrets e más práticas de autenticação.',
    true,
    $prompt$Revise o código em busca de vulnerabilidades de segurança conhecidas (OWASP Top 10).$prompt$
),
(
    'arquitetura',
    'Análise de Arquitetura',
    'bi-layers',
    'Avalia separação de concerns, acoplamento, coesão e conformidade com padrões de projeto.',
    true,
    $prompt$Analise a arquitetura do projeto: padrões utilizados, acoplamento entre módulos e aderência a boas práticas.$prompt$
),
(
    'codesmell',
    'Code Smell',
    'bi-exclamation-triangle',
    'Detecta código duplicado, métodos muito longos, complexidade ciclomática elevada e más práticas.',
    true,
    $prompt$Identifique code smells: duplicação, métodos longos, complexidade elevada e más práticas de codificação.$prompt$
),
(
    'desempenho',
    'Análise de Desempenho',
    'bi-speedometer2',
    'Aponta gargalos de performance, queries N+1, falta de cache e uso ineficiente de recursos.',
    false,
    $prompt$Analise o código em busca de gargalos de performance: queries lentas, falta de cache e uso ineficiente de recursos.$prompt$
),
(
    'dependencias',
    'Dependências',
    'bi-box-seam',
    'Verifica versões de dependências, vulnerabilidades conhecidas em pacotes e licenças.',
    false,
    $prompt$Analise as dependências do projeto: versões desatualizadas, vulnerabilidades conhecidas e licenças.$prompt$
)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS output_formats (
    id SERIAL PRIMARY KEY,
    value VARCHAR(50) NOT NULL UNIQUE,
    label VARCHAR(100) NOT NULL
);

INSERT INTO output_formats (value, label) VALUES
    ('markdown', 'Markdown'),
    ('json', 'JSON'),
    ('html', 'HTML'),
    ('pdf', 'PDF')
ON CONFLICT (value) DO NOTHING;

CREATE TABLE IF NOT EXISTS history (
    id SERIAL PRIMARY KEY,
    repo VARCHAR(500) NOT NULL,
    date TIMESTAMPTZ NOT NULL,
    issues INTEGER NOT NULL DEFAULT 0,
    severity VARCHAR(20) NOT NULL,
    agents INTEGER NOT NULL DEFAULT 0,
    time VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO history (repo, date, issues, severity, agents, time) VALUES
    ('https://github.com/time/backend-api', '2026-08-07 14:32:00+00', 12, 'Alto', 4, '1m 23s'),
    ('https://github.com/time/frontend-app', '2026-08-06 09:15:00+00', 5, 'Médio', 3, '52s'),
    ('https://github.com/exemplo/mobile-app', '2026-08-05 18:44:00+00', 8, 'Alto', 4, '1m 05s'),
    ('https://github.com/exemplo/meu-projeto', '2026-08-04 10:00:00+00', 7, 'Médio', 4, '58s'),
    ('https://github.com/time/microservice-pagamentos', '2026-08-03 22:30:00+00', 3, 'Baixo', 2, '35s')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS config (
    id INTEGER PRIMARY KEY DEFAULT 1,
    execution_mode VARCHAR(20) NOT NULL DEFAULT 'PARALELO',
    output_format_id INTEGER NOT NULL,
    skill_ids TEXT NOT NULL
);

INSERT INTO config (id, execution_mode, output_format_id, skill_ids)
VALUES (1, 'PARALELO', 1, '["seguranca","arquitetura","codesmell"]')
ON CONFLICT (id) DO NOTHING;