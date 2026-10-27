-- ALVES LIMA | Migração de referência para instalar EM OUTRO projeto Supabase.
-- NÃO executar novamente no projeto Levi já preparado em 27/10/2026.
-- Exclusivamente objetos com prefixo alq_; jamais modifica tabelas wedding_*.
create table public.alq_members (user_id uuid primary key references auth.users(id) on delete cascade,full_name text not null default '',role text not null default 'inspetor' check (role in ('admin','gestor','inspetor','leitura')),active boolean not null default false,created_at timestamptz not null default now());
create table public.alq_projects (id uuid primary key default gen_random_uuid(),name text not null,code text,location text,active boolean not null default true,created_at timestamptz not null default now());
create table public.alq_documents (id uuid primary key default gen_random_uuid(),code text,title text not null,requirement text not null default 'Geral',sector text not null default 'Geral',revision text default '00',project_id uuid references public.alq_projects(id) on delete set null,file_path text not null,file_name text not null,size_bytes bigint default 0,uploaded_by uuid not null references auth.users(id),created_at timestamptz not null default now());
create table public.alq_fvs_templates (id uuid primary key default gen_random_uuid(),code text,title text not null,service text not null,norm_ref text,revision text default '00',active boolean not null default true,created_at timestamptz not null default now());
create table public.alq_fvs_criteria (id uuid primary key default gen_random_uuid(),template_id uuid not null references public.alq_fvs_templates(id) on delete cascade,description text not null,reference text,sort_order integer not null default 0);
create table public.alq_inspections (id uuid primary key default gen_random_uuid(),code text,project_id uuid references public.alq_projects(id) on delete set null,template_id uuid not null references public.alq_fvs_templates(id),tower text,unit text,environment text,element text,inspected_at date not null default current_date,inspector_id uuid not null default auth.uid() references auth.users(id),status text not null default 'rascunho' check(status in ('rascunho','aprovada','com_pendencias','reinspecao','concluida')),general_notes text,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.alq_inspection_results (id uuid primary key default gen_random_uuid(),inspection_id uuid not null references public.alq_inspections(id) on delete cascade,criterion_id uuid not null references public.alq_fvs_criteria(id),result text not null check(result in ('conforme','nao_conforme','nao_aplicavel')),notes text,evidence_path text,created_at timestamptz not null default now(),unique(inspection_id,criterion_id));
create table public.alq_rechecks (id uuid primary key default gen_random_uuid(),result_id uuid not null references public.alq_inspection_results(id) on delete cascade,performed_by uuid not null default auth.uid() references auth.users(id),checked_at timestamptz not null default now(),outcome text not null check(outcome in ('resolvida','mantida')),notes text,evidence_path text);
create table public.alq_objectives (id uuid primary key default gen_random_uuid(),name text not null,description text,target_value numeric not null default 100,current_value numeric not null default 0,unit text not null default '%',period text,created_at timestamptz not null default now());
create table public.alq_agilean_progress (id uuid primary key default gen_random_uuid(),project_id uuid references public.alq_projects(id) on delete set null,reference_date date not null default current_date,progress_pct numeric not null check(progress_pct between 0 and 100),description text,source text not null default 'manual' check(source in ('manual','csv_agilean','api_agilean')),created_by uuid not null default auth.uid() references auth.users(id),created_at timestamptz not null default now());
create index alq_docs_requirement_idx on public.alq_documents(requirement,sector);
create index alq_docs_project_idx on public.alq_documents(project_id);
create index alq_results_inspection_idx on public.alq_inspection_results(inspection_id);
create index alq_rechecks_result_idx on public.alq_rechecks(result_id,checked_at desc);
create index alq_inspections_project_date_idx on public.alq_inspections(project_id,inspected_at desc);
create index alq_fvs_criteria_template_idx on public.alq_fvs_criteria(template_id,sort_order);
create index alq_agilean_project_date_idx on public.alq_agilean_progress(project_id,reference_date desc);
do $$ declare t text; begin
foreach t in array array['alq_members','alq_projects','alq_documents','alq_fvs_templates','alq_fvs_criteria','alq_inspections','alq_inspection_results','alq_rechecks','alq_objectives','alq_agilean_progress'] loop
execute format('alter table public.%I enable row level security',t);
execute format('grant select,insert,update,delete on public.%I to authenticated',t);
end loop; end $$;
create policy alq_members_self_read on public.alq_members for select to authenticated using(user_id=(select auth.uid()));
create policy alq_projects_select on public.alq_projects for select to authenticated using(exists(select 1 from public.alq_members m where m.user_id=(select auth.uid()) and m.active));
create policy alq_projects_write on public.alq_projects for all to authenticated using(exists(select 1 from public.alq_members m where m.user_id=(select auth.uid()) and m.active and m.role in ('admin','gestor'))) with check(exists(select 1 from public.alq_members m where m.user_id=(select auth.uid()) and m.active and m.role in ('admin','gestor')));
do $$ declare t text; member_check text; writer_check text; mgr_check text; writer text; extra_check text; begin
member_check := 'exists(select 1 from public.alq_members m where m.user_id=(select auth.uid()) and m.active)';
writer_check := 'exists(select 1 from public.alq_members m where m.user_id=(select auth.uid()) and m.active and m.role in (''admin'',''gestor'',''inspetor''))';
mgr_check := 'exists(select 1 from public.alq_members m where m.user_id=(select auth.uid()) and m.active and m.role in (''admin'',''gestor''))';
foreach t in array array['alq_documents','alq_fvs_templates','alq_fvs_criteria','alq_inspections','alq_inspection_results','alq_rechecks','alq_objectives','alq_agilean_progress'] loop
writer:=case when t in ('alq_documents','alq_fvs_templates','alq_fvs_criteria','alq_objectives') then mgr_check else writer_check end;
extra_check:=case t when 'alq_inspections' then ' and inspector_id=(select auth.uid())' when 'alq_documents' then ' and uploaded_by=(select auth.uid())' when 'alq_rechecks' then ' and performed_by=(select auth.uid())' when 'alq_agilean_progress' then ' and created_by=(select auth.uid())' else '' end;
execute format('create policy %I on public.%I for select to authenticated using(%s)',t||'_select',t,member_check);
execute format('create policy %I on public.%I for insert to authenticated with check(%s%s)',t||'_insert',t,writer,extra_check);
execute format('create policy %I on public.%I for update to authenticated using(%s) with check(%s%s)',t||'_update',t,writer,writer,case when t='alq_inspections' then extra_check else '' end);
execute format('create policy %I on public.%I for delete to authenticated using(%s)',t||'_delete',t,mgr_check);
end loop; end $$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('alq-documentos','alq-documentos',false,52428800,array['application/pdf','image/jpeg','image/png','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.ms-excel']);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('alq-evidencias','alq-evidencias',false,15728640,array['image/jpeg','image/png','image/webp']);
create policy alq_storage_select on storage.objects for select to authenticated using(bucket_id in ('alq-documentos','alq-evidencias') and exists(select 1 from public.alq_members m where m.user_id=(select auth.uid()) and m.active));
create policy alq_storage_insert on storage.objects for insert to authenticated with check(bucket_id in ('alq-documentos','alq-evidencias') and (storage.foldername(name))[1]=(select auth.uid())::text and exists(select 1 from public.alq_members m where m.user_id=(select auth.uid()) and m.active and m.role in ('admin','gestor','inspetor')));
create policy alq_storage_delete on storage.objects for delete to authenticated using(bucket_id in ('alq-documentos','alq-evidencias') and exists(select 1 from public.alq_members m where m.user_id=(select auth.uid()) and m.active and m.role in ('admin','gestor')));
-- Histórico de NC: a ocorrência original não é apagada ao ser resolvida.
create or replace function public.alq_preserve_nc() returns trigger language plpgsql set search_path = '' as $$ begin
 if new.inspection_id <> old.inspection_id or new.criterion_id <> old.criterion_id then raise exception 'A origem do critério da inspeção não pode ser alterada'; end if;
 if old.result = 'nao_conforme' and new.result <> old.result then raise exception 'NC registrada não pode ser removida: utilize a reconferência'; end if;
 return new;
end $$;
create trigger alq_preserve_nc_before_update before update on public.alq_inspection_results for each row execute function public.alq_preserve_nc();
revoke all on function public.alq_preserve_nc() from public,anon,authenticated;
-- Mantém o responsável original, protege o histórico e só encerra após todas as NCs resolvidas.
drop policy if exists alq_inspections_update on public.alq_inspections;
create policy alq_inspections_update on public.alq_inspections for update to authenticated
using(exists(select 1 from public.alq_members m where m.user_id=(select auth.uid()) and m.active and m.role in ('admin','gestor','inspetor')))
with check(exists(select 1 from public.alq_members m where m.user_id=(select auth.uid()) and m.active and m.role in ('admin','gestor','inspetor')));
create or replace function public.alq_guard_inspections() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then
   if exists(select 1 from public.alq_inspection_results r where r.inspection_id=old.id)
   then raise exception 'Inspecao com resultados nao pode ser excluida; preserve o historico'; end if;
   return old;
 end if;
 if new.inspector_id is distinct from old.inspector_id or new.template_id is distinct from old.template_id
 then raise exception 'Responsavel original e modelo FVS nao podem ser alterados'; end if;
 if new.status='aprovada' and exists(select 1 from public.alq_inspection_results r where r.inspection_id=new.id and r.result='nao_conforme')
 then raise exception 'Inspecao com nao conformidades nao pode ser aprovada sem reconferencia'; end if;
 if new.status='concluida' and exists (
   select 1 from public.alq_inspection_results r
   where r.inspection_id=new.id and r.result='nao_conforme'
     and coalesce((select z.outcome from public.alq_rechecks z where z.result_id=r.id order by z.checked_at desc,z.id desc limit 1),'mantida')<>'resolvida'
 )
 then raise exception 'Existem nao conformidades sem reconferencia resolvida'; end if;
 return new;
end $$;
create trigger alq_guard_inspections_update before update on public.alq_inspections for each row execute function public.alq_guard_inspections();
create trigger alq_guard_inspections_delete before delete on public.alq_inspections for each row execute function public.alq_guard_inspections();
revoke all on function public.alq_guard_inspections() from public,anon,authenticated;
create or replace function public.alq_guard_nc_delete() returns trigger language plpgsql set search_path='' as $$
begin
if old.result='nao_conforme' then raise exception 'NC registrada deve ser preservada e tratada por reconferencia'; end if;
return old;
end $$;
create trigger alq_guard_nc_delete before delete on public.alq_inspection_results for each row execute function public.alq_guard_nc_delete();
revoke all on function public.alq_guard_nc_delete() from public,anon,authenticated;