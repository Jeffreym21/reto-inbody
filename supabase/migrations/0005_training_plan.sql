-- ============================================================
-- LiveFitness · 0005: plan de entrenamiento + cumplimiento por fecha
--
-- 1) settings      → nombre/inicio del plan y un evento objetivo (p. ej. una maratón).
-- 2) week_plan_days       → título, objetivo, duración e instrucciones; nuevo tipo 'str' (fuerza).
-- 3) week_plan_exercises  → prescripción (series×reps / duración), indicaciones,
--                           alternativas, referencias, grupos (biseries), variante A/B.
-- 4) workout_completions  → cumplimiento POR FECHA (reemplaza el check por día de la
--                           semana, que no tenía historial).
-- 5) Endurecimiento: claves foráneas compuestas (id, user_id) para que un usuario no
--    pueda colgar filas en el día/ejercicio de otro (la FK simple solo exigía que el
--    id existiera, aunque fuera ajeno).
--
-- Esta migración contiene SOLO esquema. El contenido del plan de cada persona
-- se carga como datos, fuera del repositorio.
-- ============================================================

-- ---------- 1) settings: plan y evento ----------
alter table public.settings
  add column if not exists plan_name       text,
  add column if not exists plan_start_date date,   -- lunes de la "semana A" (el plan alterna A/B)
  add column if not exists plan_notes      jsonb,  -- [{ "title": "...", "text": "..." }]
  add column if not exists event_name      text,
  add column if not exists event_date      date;

alter table public.settings
  add constraint settings_plan_name_len     check (plan_name  is null or char_length(plan_name)  <= 100),
  add constraint settings_event_name_len    check (event_name is null or char_length(event_name) <= 60),
  add constraint settings_plan_start_monday check (plan_start_date is null or extract(isodow from plan_start_date) = 1),
  add constraint settings_plan_notes_shape  check (plan_notes is null
                                                   or (jsonb_typeof(plan_notes) = 'array' and jsonb_array_length(plan_notes) <= 12));

-- ---------- 2) week_plan_days ----------
alter table public.week_plan_days
  add column if not exists objective     text,
  add column if not exists duration_text text,
  add column if not exists instructions  text;

alter table public.week_plan_days drop constraint if exists week_plan_days_day_type_check;
alter table public.week_plan_days
  add constraint week_plan_days_day_type_check check (day_type in ('tri','str','run','rest')),
  add constraint week_plan_days_text_len check (
        char_length(label) <= 120
    and coalesce(char_length(objective), 0)     <= 160
    and coalesce(char_length(duration_text), 0) <= 60
    and coalesce(char_length(instructions), 0)  <= 1200),
  add constraint week_plan_days_id_user_key unique (id, user_id);   -- destino de las FK compuestas

-- ---------- 3) week_plan_exercises ----------
alter table public.week_plan_exercises
  add column if not exists kind         text not null default 'strength',  -- strength | core | run | note
  add column if not exists group_label  text,      -- p. ej. "Biserie A": las filas consecutivas con el mismo grupo se muestran juntas
  add column if not exists group_note   text,      -- p. ej. "4 vueltas · descansa 60–90 s"
  add column if not exists tag          text,      -- p. ej. "A1"
  add column if not exists prescription text,      -- "4 × 6–10" o "10–15 min"
  add column if not exists detail       text,      -- equipo o intensidad ("Barra + banco plano", "RPE 6–7")
  add column if not exists cue          text,      -- indicación / qué hacer
  add column if not exists alternatives text,
  add column if not exists refs         jsonb,     -- nombres para buscar imágenes de referencia
  add column if not exists rest_text    text,
  add column if not exists optional     boolean not null default false,
  add column if not exists variant      text;      -- null = todas las semanas · 'A' / 'B' = semanas alternas

alter table public.week_plan_exercises
  add constraint week_plan_exercises_kind_check    check (kind in ('strength','core','run','note')),
  add constraint week_plan_exercises_variant_check check (variant is null or variant in ('A','B')),
  add constraint week_plan_exercises_text_len check (
        char_length(name) <= 160
    and coalesce(char_length(group_label), 0)  <= 80
    and coalesce(char_length(group_note), 0)   <= 400
    and coalesce(char_length(tag), 0)          <= 24
    and coalesce(char_length(prescription), 0) <= 80
    and coalesce(char_length(detail), 0)       <= 160
    and coalesce(char_length(cue), 0)          <= 700
    and coalesce(char_length(alternatives), 0) <= 700
    and coalesce(char_length(rest_text), 0)    <= 80),
  add constraint week_plan_exercises_refs_shape check (
    refs is null or (jsonb_typeof(refs) = 'array' and jsonb_array_length(refs) <= 6
                     and not jsonb_path_exists(refs, '$[*] ? (@.type() != "string")'))),
  add constraint week_plan_exercises_id_user_key unique (id, user_id);   -- destino de la FK de completions

comment on column public.week_plan_exercises.is_done is
  'En desuso: el cumplimiento se guarda por fecha en workout_completions.';

-- ---------- 5) FK compuesta ejercicio → día (mismo dueño) ----------
alter table public.week_plan_exercises drop constraint if exists week_plan_exercises_day_id_fkey;
alter table public.week_plan_exercises
  add constraint week_plan_exercises_day_owner_fkey
  foreign key (day_id, user_id) references public.week_plan_days (id, user_id) on delete cascade;

-- ---------- 4) workout_completions: cumplimiento por fecha ----------
create table if not exists public.workout_completions (
  id           bigint generated always as identity primary key,
  user_id      uuid   not null references auth.users(id) on delete cascade,
  exercise_id  bigint not null,
  completed_on date   not null,
  created_at   timestamptz not null default now(),
  unique (user_id, exercise_id, completed_on),
  -- el bloque debe pertenecer al mismo usuario que lo marca
  foreign key (exercise_id, user_id) references public.week_plan_exercises (id, user_id) on delete cascade,
  check (completed_on between date '2020-01-01' and date '2100-01-01')
);
comment on table public.workout_completions is 'Bloques del plan marcados como hechos, por fecha. Historial real semana a semana.';
create index if not exists workout_completions_user_date_idx on public.workout_completions (user_id, completed_on desc);

alter table public.workout_completions enable row level security;
alter table public.workout_completions force row level security;

create policy "workout_completions_select_own" on public.workout_completions
  for select using ((select auth.uid()) = user_id);
create policy "workout_completions_insert_own" on public.workout_completions
  for insert with check ((select auth.uid()) = user_id);
create policy "workout_completions_update_own" on public.workout_completions
  for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "workout_completions_delete_own" on public.workout_completions
  for delete using ((select auth.uid()) = user_id);

-- Mínimo privilegio (defensa en profundidad sobre RLS): anon no necesita nada; TRUNCATE no pasa por RLS.
revoke all on table public.workout_completions from anon;
revoke truncate, references, trigger on table public.workout_completions from authenticated;
