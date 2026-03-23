-- ============================================================
-- NakanoFood — Función para eliminar cuenta de usuario
-- Ejecutar en el SQL Editor de Supabase
-- ============================================================

-- Función que el cliente puede llamar para eliminarse a sí mismo.
-- SECURITY DEFINER le permite borrar de auth.users,
-- y el ON DELETE CASCADE del schema borra todos sus datos.
create or replace function delete_user_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

-- Solo el usuario autenticado puede llamar esta función
revoke all on function delete_user_account() from public;
grant execute on function delete_user_account() to authenticated;
