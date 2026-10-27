-- Executar depois de criar/confirmar o e-mail em Supabase Auth.
-- Trocar SEU_EMAIL_AQUI pelo endereço efetivamente utilizado no aplicativo.
insert into public.alq_members (user_id,full_name,role,active)
select id,'Administrador Alves Lima','admin',true
from auth.users
where email='SEU_EMAIL_AQUI' and email_confirmed_at is not null
on conflict (user_id) do update set role='admin',active=true;
-- Se 0 linhas forem inseridas, verifique Authentication > Users e confirmação de e-mail.