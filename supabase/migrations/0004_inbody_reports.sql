-- ============================================================
-- LiveFitness · 0004: reporte InBody completo
-- Una fila por examen InBody (por usuario y día) con la composición
-- corporal, los parámetros de investigación, el control de peso que
-- sugiere el equipo y el análisis segmental (masa magra y grasa por
-- brazo izq./der., tronco y pierna izq./der.).
--
-- Los datos "titulares" (peso, % grasa, masa muscular esquelética) se
-- reflejan solos en `measurements` (source='inbody', is_official=true)
-- mediante un trigger, así las gráficas y KPIs existentes siguen
-- funcionando sin cambios.
--
-- Mismo modelo de seguridad que el resto: RLS enabled + forced, cada
-- usuario solo ve y escribe sus propias filas. Esta migración contiene
-- SOLO esquema; los valores de cada examen se cargan fuera del repo.
-- ============================================================

create table if not exists public.inbody_reports (
  id                  bigint generated always as identity primary key,
  user_id             uuid not null references auth.users(id) on delete cascade,
  measured_on         date not null,
  tested_at           timestamp,                 -- fecha/hora impresa en la hoja (sin zona horaria)
  device              text,
  height_cm           numeric(4,1),
  age_years           smallint,
  -- composición corporal
  weight_kg           numeric(5,2) not null,
  skeletal_muscle_kg  numeric(5,2),
  body_fat_kg         numeric(5,2),
  body_fat_pct        numeric(4,1),
  bmi                 numeric(4,1),
  total_body_water_l  numeric(5,2),
  protein_kg          numeric(5,2),
  minerals_kg         numeric(5,2),
  fat_free_mass_kg    numeric(5,2),
  -- parámetros de investigación
  bmr_kcal            integer,
  visceral_fat_level  smallint,
  waist_hip_ratio     numeric(3,2),
  -- control de peso sugerido por el equipo
  ideal_weight_kg     numeric(5,2),
  weight_control_kg   numeric(5,2),
  fat_control_kg      numeric(5,2),
  muscle_control_kg   numeric(5,2),
  -- análisis segmental: { arm_l|arm_r|trunk|leg_l|leg_r : { kg, pct, eval: low|normal|high } }
  segmental_lean      jsonb,
  segmental_fat       jsonb,
  -- rangos "normales" impresos en el reporte: { metrica : { min, max } }
  ranges              jsonb,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (user_id, measured_on),
  check (device is null or char_length(device) <= 40),
  check (height_cm is null or height_cm between 50 and 260),
  check (age_years is null or age_years between 1 and 120),
  check (weight_kg > 20 and weight_kg < 500),
  check (skeletal_muscle_kg is null or skeletal_muscle_kg between 0 and 300),
  check (body_fat_kg is null or body_fat_kg between 0 and 400),
  check (body_fat_pct is null or body_fat_pct between 0 and 100),
  check (bmi is null or bmi between 5 and 100),
  check (total_body_water_l is null or total_body_water_l between 0 and 300),
  check (protein_kg is null or protein_kg between 0 and 100),
  check (minerals_kg is null or minerals_kg between 0 and 50),
  check (fat_free_mass_kg is null or fat_free_mass_kg between 0 and 400),
  check (bmr_kcal is null or bmr_kcal between 300 and 6000),
  check (visceral_fat_level is null or visceral_fat_level between 1 and 30),
  check (waist_hip_ratio is null or waist_hip_ratio between 0.3 and 2.0),
  check (ideal_weight_kg is null or ideal_weight_kg between 20 and 400),
  check (weight_control_kg is null or weight_control_kg between -200 and 200),
  check (fat_control_kg is null or fat_control_kg between -200 and 200),
  check (muscle_control_kg is null or muscle_control_kg between -200 and 200),
  check (segmental_lean is null or (jsonb_typeof(segmental_lean) = 'object'
         and segmental_lean ?& array['arm_l','arm_r','trunk','leg_l','leg_r'])),
  check (segmental_fat is null or (jsonb_typeof(segmental_fat) = 'object'
         and segmental_fat ?& array['arm_l','arm_r','trunk','leg_l','leg_r'])),
  check (ranges is null or jsonb_typeof(ranges) = 'object')
);
comment on table public.inbody_reports is 'Reporte InBody completo por examen. Peso/% grasa/músculo se reflejan en measurements (source=inbody) vía trigger.';

-- ---------- RLS: cada usuario solo ve y escribe lo suyo ----------
alter table public.inbody_reports enable row level security;
alter table public.inbody_reports force row level security;

create policy "inbody_reports_select_own" on public.inbody_reports
  for select using ((select auth.uid()) = user_id);
create policy "inbody_reports_insert_own" on public.inbody_reports
  for insert with check ((select auth.uid()) = user_id);
create policy "inbody_reports_update_own" on public.inbody_reports
  for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "inbody_reports_delete_own" on public.inbody_reports
  for delete using ((select auth.uid()) = user_id);

-- ---------- Mínimo privilegio (defensa en profundidad sobre RLS) ----------
-- Supabase otorga por defecto todos los privilegios a anon/authenticated en tablas nuevas.
-- anon (sin sesión) no necesita nada aquí; y TRUNCATE no pasa por RLS, así que se revoca.
revoke all on table public.inbody_reports from anon;
revoke truncate, references, trigger on table public.inbody_reports from authenticated;

-- ---------- updated_at automático ----------
create trigger trg_inbody_reports_updated_at
  before update on public.inbody_reports
  for each row execute function public.set_updated_at();

-- ---------- Reflejar los valores titulares en measurements ----------
-- SECURITY INVOKER (por defecto): se ejecuta con los permisos de quien escribe el reporte,
-- así RLS de measurements sigue aplicando. Borrar un reporte NO borra su medición.
create or replace function public.sync_inbody_to_measurements()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  insert into public.measurements (user_id, measured_on, weight_kg, body_fat_pct, muscle_mass_kg, source, is_official)
  values (new.user_id, new.measured_on, new.weight_kg, new.body_fat_pct, new.skeletal_muscle_kg, 'inbody', true)
  on conflict (user_id, measured_on) do update
    set weight_kg      = excluded.weight_kg,
        body_fat_pct   = excluded.body_fat_pct,
        muscle_mass_kg = excluded.muscle_mass_kg,
        source         = 'inbody',
        is_official    = true;
  return new;
end;
$$;

create trigger trg_inbody_reports_sync
  after insert or update on public.inbody_reports
  for each row execute function public.sync_inbody_to_measurements();
