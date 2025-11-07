import os

configfile: "config/config.yaml"

prefix = config.get("prefix", "experiment")
mapq = config.get("mapq", 30)
fragment_max = config.get("fragment_max", 2000)
extsize = config.get("extsize", 147)
loglr_pseudo = config.get("bdgcmp_pseudo", 1e-5)
lambda_bg = config.get("bdgcmp_lambda_bg", 1.0)
peak_cutoff = config.get("peak_cutoff", 0.01)
peak_min_len = config.get("peak_min_length", extsize)

treatment_sample = "treatment"
control_sample = "control"

rule all:
    input:
        peaks=f"peaks/{prefix}.narrowPeak",
        treatment_signal=f"signal/{treatment_sample}.pileup.bdg",
        control_signal=f"signal/{control_sample}.pileup.bdg",
        loglr=f"signal/{prefix}.logLR.bdg",
        ppois=f"signal/{prefix}.ppois.bdg"

rule filter_bam:
    """Filter paired-end alignments by MAPQ and flags as in the MACS3 step-by-step guide."""
    input:
        bam=lambda wildcards: config[f"{wildcards.sample}_bam"]
    output:
        "bam/{sample}.filtered.bam"
    params:
        mapq=mapq
    threads: 4
    shell:
        (
            "samtools view -b -q {params.mapq} -f 2 -F 1804 {input.bam} | "
            "samtools sort -@ {threads} -o {output}"
        )

rule index_filtered_bam:
    input:
        "bam/{sample}.filtered.bam"
    output:
        "bam/{sample}.filtered.bam.bai"
    threads: 1
    shell:
        "samtools index {input}"

rule bam_to_bedpe:
    input:
        bam="bam/{sample}.filtered.bam"
    output:
        "bedpe/{sample}.bedpe"
    threads: 2
    shell:
        "bedtools bamtobed -bedpe -i {input.bam} > {output}"

rule bedpe_to_fragments:
    input:
        "bedpe/{sample}.bedpe"
    output:
        "bed/{sample}.fragments.bed"
    params:
        fragment_max=fragment_max
    shell:
        (
            "awk '"
            "($1==\"chrM\" || $4==\"chrM\"){next} "
            "($1==$4 && $6-$2 < {params.fragment_max})"
            "{printf \"%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n\", $1,$2,$6,$7,$8,$9}' {input} | "
            "sort -k1,1 -k2,2n > {output}"
        )

rule pileup_signal:
    input:
        "bed/{sample}.fragments.bed"
    output:
        "signal/{sample}.pileup.bdg"
    params:
        extsize=extsize
    shell:
        "macs3 pileup -i {input} -o {output} --extsize {params.extsize} -B 1"

rule loglr_track:
    input:
        treatment="signal/treatment.pileup.bdg",
        control="signal/control.pileup.bdg"
    output:
        f"signal/{prefix}.logLR.bdg"
    params:
        pseudo=loglr_pseudo
    shell:
        "macs3 bdgcmp -t {input.treatment} -c {input.control} -m logLR -p {params.pseudo} -o {output}"

rule ppois_track:
    input:
        treatment="signal/treatment.pileup.bdg",
        control="signal/control.pileup.bdg"
    output:
        f"signal/{prefix}.ppois.bdg"
    params:
        lambdabg=lambda_bg
    shell:
        "macs3 bdgcmp -t {input.treatment} -c {input.control} -m ppois -S {params.lambdabg} -o {output}"

rule peak_calling:
    input:
        f"signal/{prefix}.ppois.bdg"
    output:
        f"peaks/{prefix}.narrowPeak"
    params:
        cutoff=peak_cutoff,
        minlen=peak_min_len
    shell:
        "macs3 bdgpeakcall -i {input} -o {output} -c {params.cutoff} -l {params.minlen}"
