# Data foundation — Reto InBody

Este paquete es la base de datos y el pipeline de despliegue para tu dashboard
(`reto-inbody.html`). Está diseñado para reemplazar `window.storage` por
Supabase sin cambiar el modelo de datos que ya usa el front-end.

## Qué incluye

```
reto-inbody-backend/
├── supabase/
│   ├── config.toml
│   └── migrations/
│       ├── 0001_init_schema.sql        → tablas: settings, measurements,
│       │                                  day_logs, week_plan_days,
│       │                                  week_plan_exercises
│       ├── 0002_rls_policies.sql       → RLS: cada usuario solo ve sus datos
│       └── 0003_functions_triggers.sql → updated_at automático + siembra
│                                          de la plantilla semanal al
│                                          registrarse (igual al
│                                          DEFAULT_WEEK del HTML)
└── .github/workflows/
    ├── supabase-migrate.yml   → aplica migraciones a Supabase en cada push
    └── pages-deploy.yml       → publica reto-inbody.html en GitHub Pages
```

## Modelo de datos (resumen)

| Tabla                  | Qué guarda                                                        |
|-------------------------|--------------------------------------------------------------------|
| `settings`              | fecha del examen InBody, meta de agua, meta de peso (1 fila/usuario) |
| `measurements`          | peso, % grasa, masa muscular, medidas por zona — 1 fila por día. `source`/`is_official` distinguen tus autorregistros del InBody real del 26/09 |
| `day_logs`               | desayuno/almuerzo/cena/snacks + agua — 1 fila por día              |
| `week_plan_days`         | tu plantilla semanal (triserie/carrera/descanso)                   |
| `week_plan_exercises`    | los ejercicios de cada día, con su checkbox de completado          |

Todas las tablas tienen `user_id` y Row Level Security: nadie, ni tú viendo
la base desde el panel de otro participante, puede leer o escribir datos que
no sean los suyos. No hay ninguna tabla compartida del "reto" — cada quien
corre su propia copia privada, tal como pediste.

## Cómo ejecutar esto contra tu proyecto de Supabase

Tienes dos caminos — elige el que prefieras:

### Opción A — Yo lo ejecuto directamente en este chat
Habilita el conector de **Supabase** en la configuración de conectores de
este chat de Cowork (Ajustes → Conectores → Supabase → conectar). Una vez
conectado, dímelo y corro las 3 migraciones directamente contra tu proyecto,
verifico las políticas RLS y te confirmo que quedó todo aplicado.

### Opción B — Claude Code / Supabase CLI en tu computador
1. `npx supabase login`
2. `npx supabase link --project-ref TU_PROJECT_REF` (lo ves en Settings → General de tu proyecto Supabase)
3. `npx supabase db push` — aplica las 3 migraciones en orden.
4. Verifica en el SQL Editor de Supabase que las 5 tablas y sus políticas RLS existan.

### Opción C — Pegar el SQL manualmente
Copia el contenido de los 3 archivos de `supabase/migrations/`, en orden, en
el SQL Editor del dashboard de Supabase y ejecútalos uno por uno.

## Despliegue por GitHub

1. Crea el repo (o usa uno existente) y sube esta carpeta + tu
   `reto-inbody.html` a la raíz.
2. En **Settings → Secrets and variables → Actions** del repo, agrega:
   - `SUPABASE_ACCESS_TOKEN` (Supabase → Account → Access Tokens)
   - `SUPABASE_PROJECT_REF` (Settings → General de tu proyecto)
   - `SUPABASE_DB_PASSWORD` (la que definiste al crear el proyecto)
3. En **Settings → Pages**, fuente = "GitHub Actions".
4. Cada push a `main` que toque `supabase/migrations/**` corre las
   migraciones automáticamente; cada push que toque `reto-inbody.html`
   republica el dashboard en GitHub Pages.

## Lo que falta para que el front-end use esto de verdad

Hoy `reto-inbody.html` guarda todo en `window.storage` (local, sin login).
Para que hable con Supabase falta, en el propio HTML:

1. Cargar `@supabase/supabase-js` desde CDN e inicializar el cliente con la
   **URL** y la **anon key** de tu proyecto (son públicas, seguras de
   exponer — la protección real la da RLS, no el secreto de la key).
2. Agregar una pantalla mínima de login (recomendado: **magic link** por
   email — sin contraseñas que gestionar).
3. Reemplazar cada `window.storage.get/set` por `supabase.from(tabla).select/upsert`,
   mapeando el JSON actual (`settings`, `measurements`, `daylogs`, `week`) a
   las 5 tablas de arriba.

No lo hice en este paso porque es un cambio de frontend en sí mismo (no solo
"backend"), pero el modelo de datos ya está pensado 1:1 para que ese mapeo
sea directo. Dime si quieres que lo haga ahora y seguimos.

## Limitación conocida (heredada del front-end actual)

`week_plan_exercises.is_done` se marca por *día de la semana*, no por fecha
específica — igual que hoy en `window.storage`. Si en algún momento quieres
historial real semana a semana (ej. "hice Triserie A la semana del 18 y la
del 25, pero no la del 11"), se agrega una tabla `workout_completions
(user_id, exercise_id, completed_on date)`. Está fuera de este alcance por
ahora para no romper el comportamiento actual del dashboard.
