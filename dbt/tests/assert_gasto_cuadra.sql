-- El total del mart debe ser la suma exacta de sus tres componentes.
select periodo
from {{ ref("mart_gasto_hospital") }}
where round(costo_total, 0) <> round(recurso_humano + gastos_generales + insumos, 0)
