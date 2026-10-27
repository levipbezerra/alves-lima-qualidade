# Alves Lima — Sistema de Gestão da Qualidade

Aplicação web responsiva de controle da qualidade para a Alves Lima.

## Módulos

- **Visão geral:** contadores de FVS, documentos, RNCs e objetivos, calculados exclusivamente com dados reais.
- **Auditoria:** gestão documental e upload privado, classificação por requisito/setor, código e revisão.
- **FVS:** modelos com critérios, inspeções por obra/torre/unidade/ambiente/elemento, responsável definido pelo login, data, avaliação e evidências fotográficas.
- **Reconferência:** RNCs geradas por critérios não conformes, registro das tratativas, fotos e situação resolvida/mantida.
- **Indicadores:** objetivos e metas editáveis, aprovação de FVS e resolução de RNC.
- **Agilean:** importação controlada de arquivos CSV com `obra;data;avanco` e lançamento manual. **Não existe sincronização automática por API até receber documentação e credenciais da Agilean.**

## Arquitetura

- Frontend: JavaScript modular, CSS responsivo e HTML estático.
- Login: Supabase Auth com e-mail e senha.
- Dados: PostgreSQL Supabase, tabelas `public.alq_*`.
- Arquivos: Supabase Storage com os buckets privados `alq-documentos` e `alq-evidencias`.
- Segurança: políticas de RLS em todas as tabelas, por associação na tabela `alq_members`.
- Deploy: Vercel, sem build ou variável secreta no navegador.

### Configuração atual

O frontend já aponta para o projeto Supabase da conta Levi (`fgmhrekiowkfrqvhxorw`), com a **chave pública** de API. Nenhum segredo administrativo foi incluído no repositório. **Esse é o projeto que já hospeda os dados do casamento**, mas a Alves Lima usa tabelas, buckets e políticas de acesso com prefixos exclusivos. Para isolamento físico completo, crie um projeto Supabase próprio, rode uma migração e altere a URL e chave pública no início de `app.js`.

Os objetos `alq_*` e os buckets já foram criados no Supabase conectado em 27/10/2026. Não é necessário reaplicar a estrutura nessa mesma base.

## Primeira conta (admin)

O Supabase não possuía usuários no Auth quando o sistema foi criado. O aplicativo dispõe de **Solicitar acesso** (signup), mas usuários recém-registrados não podem acessar qualquer informação sem autorização na tabela `alq_members`.

1. Cadastre-se pelo formulário **Solicitar acesso**, com e-mail próprio e senha, confirmando o e-mail quando solicitado. Também é possível criar o usuário por **Supabase > Authentication > Users**.
2. Em **Supabase > SQL Editor**, substitua o endereço no trecho abaixo por aquele usado no Auth:

```sql
insert into public.alq_members (user_id, full_name, role, active)
select id, 'Administrador Alves Lima', 'admin', true
from auth.users
where email = 'SEU_EMAIL_AQUI'
  and email_confirmed_at is not null
on conflict (user_id) do update
  set role = 'admin', active = true;
```

3. Confirme que a consulta afetou 1 linha. Se afetar 0, verifique se o usuário existe e se o e-mail foi confirmado.
4. Entre no app com e-mail e senha. Para habilitar os demais usuários, repita a consulta inserindo `role = 'gestor'`, `'inspetor'` ou `'leitura'`.

**Importante:** mantenha o signup com confirmação de e-mail habilitada. Nunca exponha a chave `service_role` no navegador. A plataforma não cria nenhum membro aprovado automaticamente.

## Fluxo das inspeções

1. Cadastre a obra na aba **Obras e Agilean**.
2. Cadastre o **Modelo de FVS** com os critérios oficiais do serviço.
3. Clique em **Nova inspeção** e identifique o local: `Torre > Unidade > Ambiente > Elemento`.
4. Avalie cada item: Conforme / Não conforme / Não aplicável, com comentário e imagem.
5. Salve. Toda resposta não conforme gera automaticamente uma entrada na aba **Não conformidades**.
6. Realize uma **Reconferência**, registre a conclusão e a fotografia. Quando todas as NCs da ficha forem solucionadas, ela passa a Concluída.
7. Na ficha, clique em **Imprimir / PDF** e selecione **Salvar como PDF** na janela de impressão. O documento inclui identificação, local, data, critérios, resultados, observações e fotografias incorporadas.

### CSV de progresso

Exemplo em UTF-8, separado por ponto e vírgula:

```csv
obra;data;avanco
OB-001;2026-10-27;36,50
OB-001;2026-11-03;39,00
```

O valor do campo `obra` deve coincidir com o nome ou código cadastrado. A fonte aparece como `csv_agilean`, **não significa** que o registro veio de uma API em tempo real.

## Deploy na Vercel

1. Crie um novo repositório privado no GitHub de Levi, chamado `alves-lima-qualidade`.
2. Faça o upload do conteúdo desta pasta na raiz do repositório.
3. Na Vercel, importe esse GitHub e selecione framework **Other**, saída estática padrão, sem comando de build.
4. Em **Supabase > Authentication > URL Configuration**, configure a URL oficial do app e os destinos de confirmação de e-mail, se necessário.
5. Após autorização da equipe Vercel, o projeto já criado chama-se `alves-lima-qualidade`.

## Limitações desta primeira entrega

- Não foram fornecidos ainda os documentos, os modelos de FVS oficiais, a logomarca da Alves Lima, os objetivos estratégicos nem as obras. Não foi inserido conteúdo fictício.
- O Agilean não foi conectado automaticamente. É necessário definir autorização de API, recursos de leitura e a correspondência das obras.
- Os relatórios FVS são exportáveis via impressão do navegador (**Salvar como PDF**), não por geração server-side assinada.
- O sistema depende de rede para registrar inspeções e fotos: ainda não há sincronização offline de campo.
- A biblioteca documental ainda não inclui fluxo de aprovação ou arquivamento de revisões antigas; possui classificação, versão e upload seguro.
- Criar ou editar modelos de FVS deve ser restrito a documentos oficiais para manter integridade de auditoria.