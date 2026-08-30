-- ============================================================
-- NakanoFood — equivalencias de unidad declaradas
-- Run this in the Supabase SQL Editor (once, on an existing project)
-- ============================================================
--
-- Una receta que pide "8 cucharadas de azúcar" no se podía descontar de un
-- producto guardado en paquetes de 1 kg: faltaba dónde anotar cuánto pesa una
-- cucharada de ese ingrediente. Aquí van esas equivalencias.
--
-- product_id     → vale solo para ese producto de la despensa (gana a todo).
-- ingredient_key → vale para cualquier ingrediente que se llame así.
-- las dos en null → equivalencia general.
--
-- El catálogo de referencia que trae la app (cuánto pesa una taza de harina,
-- de azúcar, de arroz…) NO vive aquí: va en el código, no se sincroniza y
-- cualquier fila de esta tabla le gana.

create table unit_conversions (
  id text primary key,
  product_id text references products(id) on delete cascade,
  ingredient_key text,
  from_qty real not null,
  from_unit text not null,
  to_qty real not null,
  to_unit text not null,
  is_estimate integer default 0,
  user_id uuid references auth.users(id) on delete cascade,
  updated_at text,
  synced_at text
);
alter table unit_conversions enable row level security;
create policy "own data" on unit_conversions
  using (auth.uid() = user_id);
create policy "insert own" on unit_conversions for insert
  with check (auth.uid() = user_id);

-- Las dos consultas que hace la app: todo lo de un producto, y todo lo de un
-- nombre de ingrediente.
create index unit_conversions_product_idx
  on unit_conversions (user_id, product_id);
create index unit_conversions_ingredient_idx
  on unit_conversions (user_id, ingredient_key);
