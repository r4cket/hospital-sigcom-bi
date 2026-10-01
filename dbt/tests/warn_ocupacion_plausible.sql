{{ config(severity="warn") }}

-- Ocupacion > 200% => casi seguro camas_dotacion mal cargada en ese CC.
-- Entre 100% y 200% se tolera: es el hallazgo real de sobreocupacion /
-- pacientes en exceso (boarding), no un error de datos.
select metric, periodo, ocupacion_pct
from public.v_ocupacion_camas
where ocupacion_pct > 200
