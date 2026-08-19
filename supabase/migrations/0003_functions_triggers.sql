-- ============================================================
-- Reto InBody · Data Foundation — 0003: funciones y triggers
-- 1) updated_at automático en cada UPDATE.
-- 2) Al crear un usuario (signup), se siembra su settings vacío
--    y su plantilla semanal (triseries lun/mié/jue + carrera
--    sábado + descansos), igual al DEFAULT_WEEK del front-end.
-- ============================================================

-- ---------- updated_at genérico ----------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_settings_updated_at
  before update on public.settings
  for each row execute function public.set_updated_at();

create trigger trg_measurements_updated_at
  before update on public.measurements
  for each row execute function public.set_updated_at();

create trigger trg_day_logs_updated_at
  before update on public.day_logs
  for each row execute function public.set_updated_at();

create trigger trg_week_plan_days_updated_at
  before update on public.week_plan_days
  for each row execute function public.set_updated_at();

create trigger trg_week_plan_exercises_updated_at
  before update on public.week_plan_exercises
  for each row execute function public.set_updated_at();

-- ---------- seed automático al registrarse ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  d_id bigint;
begin
  -- settings vacío (el usuario define fecha de examen y metas en Ajustes)
  insert into public.settings (user_id) values (new.id)
  on conflict (user_id) do nothing;

  -- Lunes (1) — Triserie A
  insert into public.week_plan_days (user_id, day_of_week, day_type, label)
    values (new.id, 1, 'tri', 'Triserie A') returning id into d_id;
  insert into public.week_plan_exercises (day_id, user_id, position, name) values
    (d_id, new.id, 0, 'Sentadilla + zancada + salto'),
    (d_id, new.id, 1, 'Press banca + fondos + aperturas'),
    (d_id, new.id, 2, 'Remo + jalón + curl');

  -- Martes (2) — Descanso / movilidad
  insert into public.week_plan_days (user_id, day_of_week, day_type, label)
    values (new.id, 2, 'rest', 'Descanso / movilidad');

  -- Miércoles (3) — Triserie B
  insert into public.week_plan_days (user_id, day_of_week, day_type, label)
    values (new.id, 3, 'tri', 'Triserie B') returning id into d_id;
  insert into public.week_plan_exercises (day_id, user_id, position, name) values
    (d_id, new.id, 0, 'Peso muerto + hip thrust + curl femoral'),
    (d_id, new.id, 1, 'Press militar + elevaciones + fondos'),
    (d_id, new.id, 2, 'Dominadas + remo + face pull');

  -- Jueves (4) — Triserie C
  insert into public.week_plan_days (user_id, day_of_week, day_type, label)
    values (new.id, 4, 'tri', 'Triserie C') returning id into d_id;
  insert into public.week_plan_exercises (day_id, user_id, position, name) values
    (d_id, new.id, 0, 'Sentadilla búlgara + prensa + gemelo'),
    (d_id, new.id, 1, 'Press inclinado + cruces + tríceps'),
    (d_id, new.id, 2, 'Remo unilateral + curl + antebrazo');

  -- Viernes (5) — Descanso
  insert into public.week_plan_days (user_id, day_of_week, day_type, label)
    values (new.id, 5, 'rest', 'Descanso');

  -- Sábado (6) — Carrera 5-10 km
  insert into public.week_plan_days (user_id, day_of_week, day_type, label)
    values (new.id, 6, 'run', 'Carrera 5-10 km') returning id into d_id;
  insert into public.week_plan_exercises (day_id, user_id, position, name) values
    (d_id, new.id, 0, 'Carrera continua ritmo suave');

  -- Domingo (0) — Descanso total
  insert into public.week_plan_days (user_id, day_of_week, day_type, label)
    values (new.id, 0, 'rest', 'Descanso total');

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
