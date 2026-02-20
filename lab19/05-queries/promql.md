# PromQL — Kepler (lab19)

> Kepler exporta energía acumulada en Joules (`*_joules_total`).
> Para obtener "Watts" (potencia) usa `rate( ...[1m])` => Joules/segundo = Watts.

## 1) Baseline (¿hay series?)
# ¿Kepler está publicando datos por nodo?
count(kepler_node_platform_joules_total)

# ¿Kepler está publicando datos por contenedor?
count(kepler_container_joules_total)

# Ver algunas series (útil para validar labels)
kepler_container_joules_total
kepler_node_platform_joules_total


## 2) Potencia por nodo (Watts aprox)
# Potencia total plataforma por nodo
rate(kepler_node_platform_joules_total[1m])

# Potencia por dominio (útil para comparar)
rate(kepler_node_package_joules_total[1m])
rate(kepler_node_core_joules_total[1m])
rate(kepler_node_dram_joules_total[1m])
rate(kepler_node_uncore_joules_total[1m])

# Total cluster (suma de nodos)
sum(rate(kepler_node_platform_joules_total[1m]))


## 3) Potencia por pod (Watts) usando métricas de contenedor
# Potencia total agregada por pod (todas las contribuciones: package/core/dram/other/uncore)
sum by (container_namespace, pod_name) (
  rate(kepler_container_joules_total[1m])
)

# Variante "CPU package" por pod (si quieres aproximar CPU/PKG)
sum by (container_namespace, pod_name) (
  rate(kepler_container_package_joules_total[1m])
)

# Variante DRAM por pod
sum by (container_namespace, pod_name) (
  rate(kepler_container_dram_joules_total[1m])
)


## 4) Top pods por consumo (Watts)
# Top 10 pods por potencia total
topk(10,
  sum by (container_namespace, pod_name) (
    rate(kepler_container_joules_total[1m])
  )
)

# Top 10 pods por "CPU package"
topk(10,
  sum by (container_namespace, pod_name) (
    rate(kepler_container_package_joules_total[1m])
  )
)


## 5) Energía consumida (Joules) en una ventana
# Energía por pod en los últimos 5 minutos
sum by (container_namespace, pod_name) (
  increase(kepler_container_joules_total[5m])
)

# Top 10 por energía en 5 minutos
topk(10,
  sum by (container_namespace, pod_name) (
    increase(kepler_container_joules_total[5m])
  )
)
