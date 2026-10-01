-- Un centro de costo tiene a lo sumo una fila de costos por mes.
select centro_costo_id, periodo
from {{ source("sigcom", "costos_mensuales") }}
group by centro_costo_id, periodo
having count(*) > 1
