-- ============================================================
-- Reto InBody · Data Foundation — 0002: Row Level Security
-- Regla única en todas las tablas: cada usuario autenticado solo
-- puede leer/escribir filas donde user_id = auth.uid(). Sin
-- excepciones, sin acceso de servicio expuesto al cliente.
-- ============================================================

alter table public.settings              enable row level security;
alter table public.measurements          enable row level security;
alter table public.day_logs              enable row level security;
alter table public.week_plan_days        enable row level security;
alter table public.week_plan_exercises   enable row level security;

-- Fuerza RLS incluso para el dueño de la tabla (buena práctica en Supabase)
alter table public.settings              force row level security;
alter table public.measurements          force row level security;
alter table public.day_logs              force row level security;
alter table public.week_plan_days        force row level security;
alter table public.week_plan_exercises   force row level security;

-- ---------- settings ----------
create policy "settings_select_own" on public.settings
  for select using (auth.uid() = user_id);
create policy "settings_insert_own" on public.settings
  for insert with check (auth.uid() = user_id);
create policy "settings_update_own" on public.settings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "settings_delete_own" on public.settings
  for delete using (auth.uid() = user_id);

-- ---------- measurements ----------
create policy "measurements_select_own" on public.measurements
  for select using (auth.uid() = user_id);
create policy "measurements_insert_own" on public.measurements
  for insert with check (auth.uid() = user_id);
create policy "measurements_update_own" on public.measurements
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "measurements_delete_own" on public.measurements
  for delete using (auth.uid() = user_id);

-- ---------- day_logs ----------
create policy "day_logs_select_own" on public.day_logs
  for select using (auth.uid() = user_id);
create policy "day_logs_insert_own" on public.day_logs
  for insert with check (auth.uid() = user_id);
create policy "day_logs_update_own" on public.day_logs
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "day_logs_delete_own" on public.day_logs
  for delete using (auth.uid() = user_id);

-- ---------- week_plan_days ----------
create policy "week_plan_days_select_own" on public.week_plan_days
  for select using (auth.uid() = user_id);
create policy "week_plan_days_insert_own" on public.week_plan_days
  for insert with check (auth.uid() = user_id);
create policy "week_plan_days_update_own" on public.week_plan_days
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "week_plan_days_delete_own" on public.week_plan_days
  for delete using (auth.uid() = user_id);

-- ---------- week_plan_exercises ----------
create policy "week_plan_exercises_select_own" on public.week_plan_exercises
  for select using (auth.uid() = user_id);
create policy "week_plan_exercises_insert_own" on public.week_plan_exercises
  for insert with check (auth.uid() = user_id);
create policy "week_plan_exercises_update_own" on public.week_plan_exercises
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "week_plan_exercises_delete_own" on public.week_plan_exercises
  for delete using (auth.uid() = user_id);
