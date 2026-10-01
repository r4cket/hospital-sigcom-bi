-- Todo mes con costos debe tener su fila de produccion (mismo CC y periodo).
select cm.centro_costo_id, cm.periodo
from {{ source("sigcom", "costos_mensuales") }} cm
left join {{ source("sigcom", "produccion_mensual") }} pm
       on pm.centro_costo_id = cm.centro_costo_id
      and pm.periodo = cm.periodo
where pm.centro_costo_id is null
