-- ============================================================
-- Reto InBody · Data Foundation — 0001: esquema base
-- Modela 1:1 el estado que hoy vive en window.storage dentro de
-- reto-inbody.html: settings, measurements, daylogs, week.
-- Cada usuario ve y escribe únicamente sus propios datos (RLS
-- en 0002). No hay tabla de "reto" compartido: cada participante
-- corre su propia instancia de datos, privada, tal como pediste.
-- ============================================================

-- ---------- settings (1 fila por usuario) ----------
create table if not exists public.settings (
  user_id         uuid primary key references auth.users(id) on delete cascade,
  exam_date       date,
  water_goal_l    numeric(4,2) not null default 2.5,
  weight_goal_kg  numeric(5,2),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
comment on table public.settings is 'Fecha del examen InBody, meta de agua y meta de peso por usuario.';

-- ---------- measurements (peso / % grasa / medidas por día) ----------
create table if not exists public.measurements (
  id             bigint generated always as identity primary key,
  user_id        uuid not null references auth.users(id) on delete cascade,
  measured_on    date not null default current_date,
  weight_kg      numeric(5,2),
  body_fat_pct   numeric(4,2),
  muscle_mass_kg numeric(5,2),
  chest_cm       numeric(5,2),
  waist_cm       numeric(5,2),
  arm_l_cm       numeric(5,2),
  arm_r_cm       numeric(5,2),
  legs_cm        numeric(5,2),
  -- 'self' = registrado por ti en el dashboard; 'inbody' = resultado oficial del examen
  source         text not null default 'self' check (source in ('self','inbody')),
  is_official    boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (user_id, measured_on)
);
comment on table public.measurements is 'Un registro por usuario y día. source/is_official distinguen el InBody oficial del 26/09 de tus autorregistros.';
create index if not exists measurements_user_date_idx on public.measurements (user_id, measured_on desc);

-- ---------- day_logs (comidas + agua por día) ----------
create table if not exists public.day_logs (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  log_date    date not null default current_date,
  breakfast   text not null default '',
  lunch       text not null default '',
  dinner      text not null default '',
  snacks      text not null default '',
  water_l     numeric(3,2) not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, log_date)
);
comment on table public.day_logs is 'Registro diario de comidas + agua. Alimenta el analizador heurístico de nutrición.';
create index if not exists day_logs_user_date_idx on public.day_logs (user_id, log_date desc);

-- ---------- week_plan_days (plantilla semanal: 0=Domingo..6=Sábado) ----------
create table if not exists public.week_plan_days (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  day_type    text not null check (day_type in ('tri','run','rest')),
  label       text not null default '',
  updated_at  timestamptz not null default now(),
  unique (user_id, day_of_week)
);
comment on table public.week_plan_days is 'Plantilla semanal de entrenamiento (triserie/carrera/descanso) por usuario.';

-- ---------- week_plan_exercises (ejercicios dentro de cada día) ----------
create table if not exists public.week_plan_exercises (
  id          bigint generated always as identity primary key,
  day_id      bigint not null references public.week_plan_days(id) on delete cascade,
  -- denormalizado a propósito: simplifica las políticas RLS (sin JOIN) y los índices
  user_id     uuid not null references auth.users(id) on delete cascade,
  position    smallint not null default 0,
  name        text not null,
  is_done     boolean not null default false,
  updated_at  timestamptz not null default now(),
  unique (day_id, position)
);
comment on table public.week_plan_exercises is 'Ejercicios de cada día de la plantilla, con su checkbox de completado.';
create index if not exists week_plan_exercises_day_idx on public.week_plan_exercises (day_id, position);

-- Nota de diseño (léelo antes de extender):
-- El front-end actual marca "completado" a nivel de día-de-la-semana, no de
-- fecha concreta (p.ej. "Lunes" queda en done=true hasta que lo desmarques,
-- sin importar de qué semana). Esta migración replica ese mismo modelo para
-- no romper compatibilidad. Si más adelante quieres historial real semana a
-- semana, se añade una tabla `workout_completions (user_id, exercise_id,
-- completed_on date)` — te la dejo lista para pedir cuando quieras.
