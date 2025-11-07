# MACS3 Snakemake pipeline

Este repositorio contiene un pipeline de [Snakemake](https://snakemake.readthedocs.io/) que reproduce los pasos descritos en la guía "Advanced: Step-by-step Peak Calling" de MACS3. El flujo de trabajo parte de archivos BAM de tratamiento y control, aplica los filtros de alineamiento recomendados y genera pistas bedGraph junto con la llamada final de picos utilizando `macs3 bdgpeakcall`.

## Requisitos

* [Snakemake](https://snakemake.readthedocs.io/)
* [samtools](http://www.htslib.org/)
* [bedtools](https://bedtools.readthedocs.io/)
* [MACS3](https://macs3-project.github.io/MACS/)

Asegúrate de que los binarios `samtools`, `bedtools` y `macs3` estén disponibles en tu `$PATH`.

## Estructura

```
├── Snakefile
├── config
│   └── config.yaml
├── bam/
├── bed/
├── bedpe/
├── peaks/
└── signal/
```

Los directorios `bam/`, `bed/`, `bedpe/`, `signal/` y `peaks/` se crean automáticamente y se utilizan para los resultados intermedios y finales.

## Configuración

Edita `config/config.yaml` para apuntar a tus archivos BAM y ajustar los parámetros clave:

```yaml
prefix: macs3_pipeline            # Prefijo para los archivos de salida

# Archivos BAM de entrada
# Sustituye estas rutas por las de tus datos
# Tratamiento
# Control

treatment_bam: data/treatment.bam
control_bam: data/control.bam

# Filtros y parámetros del flujo
mapq: 30                  # Umbral de calidad de mapeo
fragment_max: 2000        # Longitud máxima permitida para los fragmentos
extsize: 147              # Tamaño de extensión utilizado por MACS3
bdgcmp_pseudo: 1.0e-5     # Pseudo cuenta para el cálculo log-likelihood
bdgcmp_lambda_bg: 1.0     # Lambda de fondo para la métrica ppois
peak_cutoff: 0.01         # Umbral de corte para `macs3 bdgpeakcall`
peak_min_length: 147      # Longitud mínima de pico
```

## Ejecución

1. Ajusta `config/config.yaml` con tus rutas de tratamiento y control.
2. Ejecuta Snakemake indicando el número de hilos deseado, por ejemplo:

   ```bash
   snakemake --cores 8
   ```

Esto generará los siguientes resultados principales:

* `signal/treatment.pileup.bdg`: cobertura normalizada del tratamiento.
* `signal/control.pileup.bdg`: cobertura normalizada del control.
* `signal/<prefix>.logLR.bdg`: pista de log-likelihood ratio.
* `signal/<prefix>.ppois.bdg`: pista basada en la métrica ppois.
* `peaks/<prefix>.narrowPeak`: picos finales llamdos por `macs3 bdgpeakcall`.

## Notas

* El paso `filter_bam` filtra lecturas mal mapeadas, duplicadas o con baja calidad (`MAPQ < mapq`) utilizando las banderas recomendadas (manteniendo pares propios `-f 2` y eliminando lecturas secundarias, suplementarias y duplicadas mediante `-F 1804`).
* `bedtools bamtobed -bedpe` transforma los pares en formato BEDPE y posteriormente se filtran los fragmentos cuya longitud excede `fragment_max`, que provienen de cromosomas distintos o de `chrM` (mitocondrial).
* `macs3 pileup`, `macs3 bdgcmp` y `macs3 bdgpeakcall` siguen exactamente la secuencia de comandos detallada en la guía avanzada de MACS3.
