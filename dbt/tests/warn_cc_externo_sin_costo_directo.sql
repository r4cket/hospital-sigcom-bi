{{ config(severity="warn") }}

-- Regla de negocio: el "Centro de Costos Externo" no debería cargar costo
-- directo propio (su gasto se imputa desde otros centros). Si aparece, hay
-- que revisar la fuente. Es "warn" porque hoy ya ocurre desde 2025 y es un
-- hallazgo conocido, no un bloqueo de la carga.
select cc.nombre, cm.periodo, cm.costo_directo
from {{ source("sigcom", "costos_mensuales") }} cm
join {{ source("sigcom", "centros_costo") }} cc on cc.id = cm.centro_costo_id
where cc.nombre ilike '%externo%'
  and cm.costo_directo > 0
