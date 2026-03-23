-- ============================================================
-- NakanoFood — Supabase schema
-- Run this in the Supabase SQL Editor (once, on a new project)
-- ============================================================

-- Enable Row Level Security helper
create extension if not exists "uuid-ossp";

-- ── product_categories ───────────────────────────────────────
create table product_categories (
  id text primary key,
  name text not null,
  is_custom integer default 0,
  icon text,
  color text,
  user_id uuid references auth.users(id) on delete cascade,
  updated_at text,
  synced_at text
);
alter table product_categories enable row level security;
create policy "own data" on product_categories
  using (auth.uid() = user_id);
create policy "insert own" on product_categories for insert
  with check (auth.uid() = user_id);

-- ── product_subcategories ────────────────────────────────────
create table product_subcategories (
  id text primary key,
  category_id text references product_categories(id) on delete cascade,
  name text not null,
  user_id uuid references auth.users(id) on delete cascade,
  updated_at text,
  synced_at text
);
alter table product_subcategories enable row level security;
create policy "own data" on product_subcategories
  using (auth.uid() = user_id);
create policy "insert own" on product_subcategories for insert
  with check (auth.uid() = user_id);

-- ── products ─────────────────────────────────────────────────
create table products (
  id text primary key,
  name text not null,
  category_id text,
  subcategory_id text,
  unit text not null default 'unidad',
  last_price real default 0,
  price_ref_qty real default 1.0,
  quantity_to_maintain real default 1,
  current_quantity real default 0,
  last_place text,
  notes text,
  created_at text not null,
  updated_at text not null,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table products enable row level security;
create policy "own data" on products
  using (auth.uid() = user_id);
create policy "insert own" on products for insert
  with check (auth.uid() = user_id);

-- ── nutritional_values ───────────────────────────────────────
create table nutritional_values (
  id text primary key,
  product_id text references products(id) on delete cascade,
  serving_size real,
  serving_unit text,
  kcal real, carbs real, sugars real, fiber real,
  total_fats real, saturated_fats real, trans_fats real,
  proteins real, sodium real,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table nutritional_values enable row level security;
create policy "own data" on nutritional_values
  using (auth.uid() = user_id);
create policy "insert own" on nutritional_values for insert
  with check (auth.uid() = user_id);

-- ── product_price_history ────────────────────────────────────
create table product_price_history (
  id text primary key,
  product_id text references products(id) on delete cascade,
  price real not null,
  price_ref_qty real default 1.0,
  unit text not null,
  purchased_at text not null,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table product_price_history enable row level security;
create policy "own data" on product_price_history
  using (auth.uid() = user_id);
create policy "insert own" on product_price_history for insert
  with check (auth.uid() = user_id);

-- ── recipes ──────────────────────────────────────────────────
create table recipes (
  id text primary key,
  name text not null,
  type text not null,
  description text,
  main_image_path text,
  portions integer default 1,
  prep_time integer,
  cook_time integer,
  estimated_cost real default 0,
  notes text,
  created_at text not null,
  updated_at text not null,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table recipes enable row level security;
create policy "own data" on recipes
  using (auth.uid() = user_id);
create policy "insert own" on recipes for insert
  with check (auth.uid() = user_id);

-- ── recipe_ingredients ───────────────────────────────────────
create table recipe_ingredients (
  id text primary key,
  recipe_id text references recipes(id) on delete cascade,
  product_id text,
  product_name text not null,
  quantity real not null,
  unit text not null,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table recipe_ingredients enable row level security;
create policy "own data" on recipe_ingredients
  using (auth.uid() = user_id);
create policy "insert own" on recipe_ingredients for insert
  with check (auth.uid() = user_id);

-- ── recipe_steps ─────────────────────────────────────────────
create table recipe_steps (
  id text primary key,
  recipe_id text references recipe_ingredients(id) on delete cascade,
  step_number integer not null,
  description text not null,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table recipe_steps enable row level security;
create policy "own data" on recipe_steps
  using (auth.uid() = user_id);
create policy "insert own" on recipe_steps for insert
  with check (auth.uid() = user_id);

-- ── recipe_images ────────────────────────────────────────────
create table recipe_images (
  id text primary key,
  recipe_id text references recipes(id) on delete cascade,
  image_path text not null,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table recipe_images enable row level security;
create policy "own data" on recipe_images
  using (auth.uid() = user_id);
create policy "insert own" on recipe_images for insert
  with check (auth.uid() = user_id);

-- ── meal_categories ──────────────────────────────────────────
create table meal_categories (
  id text primary key,
  name text not null,
  default_time text,
  color text default '#2E7D32',
  notification_enabled integer default 0,
  notification_minutes_before integer default 15,
  is_custom integer default 0,
  updated_at text,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table meal_categories enable row level security;
create policy "own data" on meal_categories
  using (auth.uid() = user_id);
create policy "insert own" on meal_categories for insert
  with check (auth.uid() = user_id);

-- ── meal_category_days ───────────────────────────────────────
create table meal_category_days (
  id text primary key,
  category_id text references meal_categories(id) on delete cascade,
  day_of_week integer not null,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table meal_category_days enable row level security;
create policy "own data" on meal_category_days
  using (auth.uid() = user_id);
create policy "insert own" on meal_category_days for insert
  with check (auth.uid() = user_id);

-- ── meal_plans ───────────────────────────────────────────────
create table meal_plans (
  id text primary key,
  date text not null,
  category_id text references meal_categories(id),
  notes text,
  updated_at text,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table meal_plans enable row level security;
create policy "own data" on meal_plans
  using (auth.uid() = user_id);
create policy "insert own" on meal_plans for insert
  with check (auth.uid() = user_id);

-- ── meal_plan_items ──────────────────────────────────────────
create table meal_plan_items (
  id text primary key,
  meal_plan_id text references meal_plans(id) on delete cascade,
  title text not null,
  recipe_id text references recipes(id) on delete set null,
  sort_order integer default 0,
  updated_at text,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table meal_plan_items enable row level security;
create policy "own data" on meal_plan_items
  using (auth.uid() = user_id);
create policy "insert own" on meal_plan_items for insert
  with check (auth.uid() = user_id);

-- ── shopping_sessions ────────────────────────────────────────
create table shopping_sessions (
  id text primary key,
  created_at text not null,
  completed_at text,
  total_cost real default 0,
  status text default 'active',
  notes text,
  updated_at text,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table shopping_sessions enable row level security;
create policy "own data" on shopping_sessions
  using (auth.uid() = user_id);
create policy "insert own" on shopping_sessions for insert
  with check (auth.uid() = user_id);

-- ── shopping_items ───────────────────────────────────────────
create table shopping_items (
  id text primary key,
  session_id text references shopping_sessions(id) on delete cascade,
  product_id text,
  product_name text not null,
  planned_quantity real not null,
  actual_quantity real,
  unit text not null,
  planned_price real default 0,
  actual_price real default 0,
  is_purchased integer default 0,
  category_id text,
  category_name text,
  subcategory_id text,
  subcategory_name text,
  last_place text,
  updated_at text,
  user_id uuid references auth.users(id) on delete cascade,
  synced_at text
);
alter table shopping_items enable row level security;
create policy "own data" on shopping_items
  using (auth.uid() = user_id);
create policy "insert own" on shopping_items for insert
  with check (auth.uid() = user_id);
