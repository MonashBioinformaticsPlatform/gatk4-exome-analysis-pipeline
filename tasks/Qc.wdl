version 1.0

## Copyright Broad Institute, 2018
##
## This WDL defines tasks used for QC of human whole-genome or exome sequencing data.
##
## Runtime parameters are often optimized for Broad's Google Cloud Platform implementation.
## For program versions, see docker containers.
##
## LICENSING :
## This script is released under the WDL source code license (BSD-3) (see LICENSE in
## https://github.com/broadinstitute/wdl). Note however that the programs it calls may
## be subject to different licenses. Users are responsible for checking that they are
## authorized to run all programs before running this script. Please see the docker
## page at https://hub.docker.com/r/broadinstitute/genomes-in-the-cloud/ for detailed
## licensing information pertaining to the included programs.

# Collect sequencing yield quality metrics
task CollectQualityYieldMetrics {
  input {
    File input_bam
    String metrics_filename
    Int preemptible_tries
  }

  Int disk_size = ceil(size(input_bam, "GB")) + 20

  command {
    java -Xms2000m -Xmx4000m -jar /usr/gitc/picard.jar \
      CollectQualityYieldMetrics \
      INPUT=~{input_bam} \
      OQ=true \
      OUTPUT=~{metrics_filename}
  }
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    disks: "local-disk " + disk_size + " HDD"
    memory: "6 GB"
    preemptible: preemptible_tries
  }
  output {
    File quality_yield_metrics = "~{metrics_filename}"
  }
}

# Collect base quality and insert size metrics
task CollectUnsortedReadgroupBamQualityMetrics {
  input {
    File input_bam
    String output_bam_prefix
    Int preemptible_tries
  }

  Int disk_size = ceil(size(input_bam, "GB")) + 20

  command {
    java -Xms6000m -Xmx6000m -jar /usr/gitc/picard.jar \
      CollectMultipleMetrics \
      INPUT=~{input_bam} \
      OUTPUT=~{output_bam_prefix} \
      ASSUME_SORTED=true \
      PROGRAM=null \
      PROGRAM=CollectBaseDistributionByCycle \
      PROGRAM=CollectInsertSizeMetrics \
      PROGRAM=MeanQualityByCycle \
      PROGRAM=QualityScoreDistribution \
      METRIC_ACCUMULATION_LEVEL=null \
      METRIC_ACCUMULATION_LEVEL=ALL_READS

    touch ~{output_bam_prefix}.insert_size_metrics
    touch ~{output_bam_prefix}.insert_size_histogram.pdf
  }
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    memory: "8 GB"
    disks: "local-disk " + disk_size + " HDD"
    preemptible: preemptible_tries
  }
  output {
    File base_distribution_by_cycle_pdf = "~{output_bam_prefix}.base_distribution_by_cycle.pdf"
    File base_distribution_by_cycle_metrics = "~{output_bam_prefix}.base_distribution_by_cycle_metrics"
    File insert_size_histogram_pdf = "~{output_bam_prefix}.insert_size_histogram.pdf"
    File insert_size_metrics = "~{output_bam_prefix}.insert_size_metrics"
    File quality_by_cycle_pdf = "~{output_bam_prefix}.quality_by_cycle.pdf"
    File quality_by_cycle_metrics = "~{output_bam_prefix}.quality_by_cycle_metrics"
    File quality_distribution_pdf = "~{output_bam_prefix}.quality_distribution.pdf"
    File quality_distribution_metrics = "~{output_bam_prefix}.quality_distribution_metrics"
  }
}

# Collect alignment summary and GC bias quality metrics
task CollectReadgroupBamQualityMetrics {
  input {
    File input_bam
    File input_bam_index
    String output_bam_prefix
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    Boolean collect_gc_bias_metrics = true
    Int preemptible_tries
  }

  Float ref_size = size(ref_fasta, "GB") + size(ref_fasta_index, "GB") + size(ref_dict, "GB")
  Int disk_size = ceil(size(input_bam, "GB") + ref_size) + 20

  command {
    # These are optionally generated, but need to exist for Cromwell's sake
    touch ~{output_bam_prefix}.gc_bias.detail_metrics \
      ~{output_bam_prefix}.gc_bias.pdf \
      ~{output_bam_prefix}.gc_bias.summary_metrics

    java -Xms6000m -Xmx6000m -jar /usr/gitc/picard.jar \
      CollectMultipleMetrics \
      INPUT=~{input_bam} \
      REFERENCE_SEQUENCE=~{ref_fasta} \
      OUTPUT=~{output_bam_prefix} \
      ASSUME_SORTED=true \
      PROGRAM=null \
      PROGRAM=CollectAlignmentSummaryMetrics \
      ~{true='PROGRAM="CollectGcBiasMetrics"' false="" collect_gc_bias_metrics} \
      METRIC_ACCUMULATION_LEVEL=null \
      METRIC_ACCUMULATION_LEVEL=READ_GROUP
  }
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    memory: "8 GB"
    disks: "local-disk " + disk_size + " HDD"
    preemptible: preemptible_tries
  }
  output {
    File alignment_summary_metrics = "~{output_bam_prefix}.alignment_summary_metrics"
    File gc_bias_detail_metrics = "~{output_bam_prefix}.gc_bias.detail_metrics"
    File gc_bias_pdf = "~{output_bam_prefix}.gc_bias.pdf"
    File gc_bias_summary_metrics = "~{output_bam_prefix}.gc_bias.summary_metrics"
  }
}

# Collect quality metrics from the aggregated bam
task CollectAggregationMetrics {
  input {
    File input_bam
    File input_bam_index
    String output_bam_prefix
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    Boolean collect_gc_bias_metrics = true
    Int preemptible_tries
  }

  Float ref_size = size(ref_fasta, "GB") + size(ref_fasta_index, "GB") + size(ref_dict, "GB")
  Int disk_size = ceil(size(input_bam, "GB") + ref_size) + 20

  command {
    # These are optionally generated, but need to exist for Cromwell's sake
    touch ~{output_bam_prefix}.gc_bias.detail_metrics \
      ~{output_bam_prefix}.gc_bias.pdf \
      ~{output_bam_prefix}.gc_bias.summary_metrics \
      ~{output_bam_prefix}.insert_size_metrics \
      ~{output_bam_prefix}.insert_size_histogram.pdf

    java -Xms6000m -Xmx6000m -jar /usr/gitc/picard.jar \
      CollectMultipleMetrics \
      INPUT=~{input_bam} \
      REFERENCE_SEQUENCE=~{ref_fasta} \
      OUTPUT=~{output_bam_prefix} \
      ASSUME_SORTED=true \
      PROGRAM=null \
      PROGRAM=CollectAlignmentSummaryMetrics \
      PROGRAM=CollectInsertSizeMetrics \
      PROGRAM=CollectSequencingArtifactMetrics \
      PROGRAM=QualityScoreDistribution \
      ~{true='PROGRAM="CollectGcBiasMetrics"' false="" collect_gc_bias_metrics} \
      METRIC_ACCUMULATION_LEVEL=null \
      METRIC_ACCUMULATION_LEVEL=SAMPLE \
      METRIC_ACCUMULATION_LEVEL=LIBRARY
  }
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    memory: "8 GB"
    disks: "local-disk " + disk_size + " HDD"
    preemptible: preemptible_tries
  }
  output {
    File alignment_summary_metrics = "~{output_bam_prefix}.alignment_summary_metrics"
    File bait_bias_detail_metrics = "~{output_bam_prefix}.bait_bias_detail_metrics"
    File bait_bias_summary_metrics = "~{output_bam_prefix}.bait_bias_summary_metrics"
    File gc_bias_detail_metrics = "~{output_bam_prefix}.gc_bias.detail_metrics"
    File gc_bias_pdf = "~{output_bam_prefix}.gc_bias.pdf"
    File gc_bias_summary_metrics = "~{output_bam_prefix}.gc_bias.summary_metrics"
    File insert_size_histogram_pdf = "~{output_bam_prefix}.insert_size_histogram.pdf"
    File insert_size_metrics = "~{output_bam_prefix}.insert_size_metrics"
    File pre_adapter_detail_metrics = "~{output_bam_prefix}.pre_adapter_detail_metrics"
    File pre_adapter_summary_metrics = "~{output_bam_prefix}.pre_adapter_summary_metrics"
    File quality_distribution_pdf = "~{output_bam_prefix}.quality_distribution.pdf"
    File quality_distribution_metrics = "~{output_bam_prefix}.quality_distribution_metrics"
    File error_summary_metrics = "~{output_bam_prefix}.error_summary_metrics"
  }
}

# Check that the fingerprints of separate readgroups all match
task CrossCheckFingerprints {
  input {
    Array[File] input_bams
    Array[File] input_bam_indexes
    File? haplotype_database_file
    String metrics_filename
    Float total_input_size
    Int preemptible_tries
    Float lod_threshold
    String cross_check_by
  }

  Int disk_size = ceil(total_input_size) + 20

  command <<<
    java -Dsamjdk.buffer_size=131072 \
      -XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Xms2000m -Xmx2000m \
      -jar /usr/gitc/picard.jar \
      CrosscheckFingerprints \
      OUTPUT=~{metrics_filename} \
      HAPLOTYPE_MAP=~{haplotype_database_file} \
      EXPECT_ALL_GROUPS_TO_MATCH=true \
      INPUT=~{sep=' INPUT=' input_bams} \
      LOD_THRESHOLD=~{lod_threshold} \
      CROSSCHECK_BY=~{cross_check_by}
  >>>
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    preemptible: preemptible_tries
    memory: "3 GB"
    disks: "local-disk " + disk_size + " HDD"
  }
  output {
    File cross_check_fingerprints_metrics = "~{metrics_filename}"
  }
}

# Check that the fingerprint of the sample BAM matches the sample array
task CheckFingerprint {
  input {
    File input_bam
    File input_bam_index
    String output_basename
    File? haplotype_database_file
    File? genotypes
    File? genotypes_index
    String sample
    Int preemptible_tries
  }

  Int disk_size = ceil(size(input_bam, "GB")) + 20

  command <<<
    java -Dsamjdk.buffer_size=131072 \
      -XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Xms1024m -Xmx1024m \
      -jar /usr/gitc/picard.jar \
      CheckFingerprint \
      INPUT=~{input_bam} \
      OUTPUT=~{output_basename} \
      GENOTYPES=~{genotypes} \
      HAPLOTYPE_MAP=~{haplotype_database_file} \
      SAMPLE_ALIAS="~{sample}" \
      IGNORE_READ_GROUPS=true

  >>>
 runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    preemptible: preemptible_tries
    memory: "2 GB"
    disks: "local-disk " + disk_size + " HDD"
  }
  output {
    File summary_metrics = "~{output_basename}.fingerprinting_summary_metrics"
    File detail_metrics = "~{output_basename}.fingerprinting_detail_metrics"
  }
}

task CheckPreValidation {
  input {
    File duplication_metrics
    File chimerism_metrics
    Float max_duplication_in_reasonable_sample
    Float max_chimerism_in_reasonable_sample
    Int preemptible_tries
  }
  
  command <<<
    set -o pipefail
    set -e

    grep -A 1 PERCENT_DUPLICATION ~{duplication_metrics} > duplication.csv
    grep -A 3 PCT_CHIMERAS ~{chimerism_metrics} | grep -v OF_PAIR > chimerism.csv

    python <<CODE

    import csv
    with open('duplication.csv') as dupfile:
      reader = csv.DictReader(dupfile, delimiter='\t')
      for row in reader:
        with open("duplication_value.txt","w") as file:
          file.write(row['PERCENT_DUPLICATION'])
          file.close()

    with open('chimerism.csv') as chimfile:
      reader = csv.DictReader(chimfile, delimiter='\t')
      for row in reader:
        with open("chimerism_value.txt","w") as file:
          file.write(row['PCT_CHIMERAS'])
          file.close()

    CODE

  >>>
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    preemptible: preemptible_tries
    docker: "python:2.7"
    memory: "2 GB"
  }
  output {
    Float duplication_rate = read_float("duplication_value.txt")
    Float chimerism_rate = read_float("chimerism_value.txt")
    Boolean is_outlier_data = duplication_rate > max_duplication_in_reasonable_sample || chimerism_rate > max_chimerism_in_reasonable_sample
  }
}

task ValidateSamFile {
  input {
    File input_bam
    File? input_bam_index
    String report_filename
    File ref_dict
    File ref_fasta
    File ref_fasta_index
    Int? max_output
    Array[String]? ignore
    Boolean? is_outlier_data
    Int preemptible_tries
  }

  Float ref_size = size(ref_fasta, "GB") + size(ref_fasta_index, "GB") + size(ref_dict, "GB")
  Int disk_size = ceil(size(input_bam, "GB") + ref_size) + 20

  command {
    java -Xms6000m -Xmx6000m -jar /usr/gitc/picard.jar \
      ValidateSamFile \
      INPUT=~{input_bam} \
      OUTPUT=~{report_filename} \
      REFERENCE_SEQUENCE=~{ref_fasta} \
      ~{"MAX_OUTPUT=" + max_output} \
      IGNORE=~{default="null" sep=" IGNORE=" ignore} \
      MODE=VERBOSE \
      ~{default='SKIP_MATE_VALIDATION=false' true='SKIP_MATE_VALIDATION=true' false='SKIP_MATE_VALIDATION=false' is_outlier_data} \
      IS_BISULFITE_SEQUENCED=false
  }
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    preemptible: preemptible_tries
    memory: "8 GB"
    disks: "local-disk " + disk_size + " HDD"
  }
  output {
    File report = "~{report_filename}"
  }
}

# Note these tasks will break if the read lengths in the bam are greater than 250.
task CollectWgsMetrics {
  input {
    File input_bam
    File input_bam_index
    String metrics_filename
    File wgs_coverage_interval_list
    File ref_fasta
    File ref_fasta_index
    Int read_length
    Int preemptible_tries
  }

  Float ref_size = size(ref_fasta, "GB") + size(ref_fasta_index, "GB")
  Int disk_size = ceil(size(input_bam, "GB") + ref_size) + 20

  command {
    java -Xms2000m -Xmx2000m -jar /usr/gitc/picard.jar \
      CollectWgsMetrics \
      INPUT=~{input_bam} \
      VALIDATION_STRINGENCY=SILENT \
      REFERENCE_SEQUENCE=~{ref_fasta} \
      INCLUDE_BQ_HISTOGRAM=true \
      INTERVALS=~{wgs_coverage_interval_list} \
      OUTPUT=~{metrics_filename} \
      USE_FAST_ALGORITHM=true \
      READ_LENGTH=~{read_length}
  }
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    preemptible: preemptible_tries
    memory: "3 GB"
    disks: "local-disk " + disk_size + " HDD"
  }
  output {
    File metrics = "~{metrics_filename}"
  }
}

# Collect raw WGS metrics (commonly used QC thresholds)
task CollectRawWgsMetrics {
  input {
    File input_bam
    File input_bam_index
    String metrics_filename
    File wgs_coverage_interval_list
    File ref_fasta
    File ref_fasta_index
    Int read_length
    Int preemptible_tries
  }

  Float ref_size = size(ref_fasta, "GB") + size(ref_fasta_index, "GB")
  Int disk_size = ceil(size(input_bam, "GB") + ref_size) + 20

  String main_memory = if(disk_size < 110) then "6 GB" else "8 GB"
  String java_memory = if(disk_size < 110) then "-Xmx4000m" else "-Xmx6000m"

  command {
    java ${java_memory} -jar /usr/gitc/picard.jar \
      CollectRawWgsMetrics \
      INPUT=~{input_bam} \
      VALIDATION_STRINGENCY=SILENT \
      REFERENCE_SEQUENCE=~{ref_fasta} \
      INCLUDE_BQ_HISTOGRAM=true \
      INTERVALS=~{wgs_coverage_interval_list} \
      OUTPUT=~{metrics_filename} \
      USE_FAST_ALGORITHM=true \
      READ_LENGTH=~{read_length}
  }
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    preemptible: preemptible_tries
    memory: main_memory
    disks: "local-disk " + disk_size + " HDD"
  }
  output {
    File metrics = "~{metrics_filename}"
  }
}

task CollectHsMetrics {
  input {
    File input_bam
    File input_bam_index
    File ref_fasta
    File ref_fasta_index
    String metrics_filename
    File target_interval_list
    File bait_interval_list
    Int preemptible_tries
  }

  Float ref_size = size(ref_fasta, "GB") + size(ref_fasta_index, "GB")
  Int disk_size = ceil(size(input_bam, "GB") + ref_size) + 20

  # Try to fit the input bam into memory, within reason.
  Int rounded_bam_size = ceil(size(input_bam, "GB") + 0.5)
  Int java_mem_size = if (rounded_bam_size > 9) then 9 else rounded_bam_size
  Int final_java_mem_size = if (java_mem_size < 2) then 2 else java_mem_size
  Int mem_size = final_java_mem_size + 2

  # There are probably more metrics we want to generate with this tool
  command {
    java -Xmx~{final_java_mem_size * 1000}m -jar /usr/gitc/picard.jar \
      CollectHsMetrics \
      INPUT=~{input_bam} \
      REFERENCE_SEQUENCE=~{ref_fasta} \
      VALIDATION_STRINGENCY=SILENT \
      TARGET_INTERVALS=~{target_interval_list} \
      BAIT_INTERVALS=~{bait_interval_list} \
      METRIC_ACCUMULATION_LEVEL=null \
      METRIC_ACCUMULATION_LEVEL=SAMPLE \
      METRIC_ACCUMULATION_LEVEL=LIBRARY \
      OUTPUT=~{metrics_filename}
  }

  runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    preemptible: preemptible_tries
    memory: "~{mem_size} GB"
    disks: "local-disk " + disk_size + " HDD"
  }

  output {
    File metrics = metrics_filename
  }
}

# Generate a checksum per readgroup
task CalculateReadGroupChecksum {
  input {
    File input_bam
    File input_bam_index
    String read_group_md5_filename
    Int preemptible_tries
  }

  Int disk_size = ceil(size(input_bam, "GB")) + 20

  command {
    java -Xmx1000m -jar /usr/gitc/picard.jar \
      CalculateReadGroupChecksum \
      INPUT=~{input_bam} \
      OUTPUT=~{read_group_md5_filename}
  }
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    preemptible: preemptible_tries
    memory: "2 GB"
    disks: "local-disk " + disk_size + " HDD"
  }
  output {
    File md5_file = "~{read_group_md5_filename}"
  }
}

# Validate a GVCF with -gvcf specific validation
task ValidateGVCF {
  input {
    File input_vcf
    File input_vcf_index
    File ref_fasta
    File ref_fasta_index
    File ref_dict
    File dbsnp_vcf
    File dbsnp_vcf_index
    File calling_interval_list
    Int preemptible_tries
    String gatk_docker = "us.gcr.io/broad-gatk/gatk:4.0.10.1"
  }

  Float ref_size = size(ref_fasta, "GB") + size(ref_fasta_index, "GB") + size(ref_dict, "GB")
  Int disk_size = ceil(size(input_vcf, "GB") + size(dbsnp_vcf, "GB") + ref_size) + 20

  command {
    gatk --java-options -Xmx3000m \
      ValidateVariants \
      -V ~{input_vcf} \
      -R ~{ref_fasta} \
      -L ~{calling_interval_list} \
      -gvcf \
      --validation-type-to-exclude ALLELES \
      --dbsnp ~{dbsnp_vcf}
  }
  runtime {
    docker: gatk_docker
    preemptible: preemptible_tries
    memory: "4 GB"
    disks: "local-disk " + disk_size + " HDD"
  }
}

# Collect variant calling metrics from GVCF output
task CollectGvcfCallingMetrics {
  input {
    File input_vcf
    File input_vcf_index
    String metrics_basename
    File dbsnp_vcf
    File dbsnp_vcf_index
    File ref_dict
    File evaluation_interval_list
    Int preemptible_tries
  }

  Int disk_size = ceil(size(input_vcf, "GB") + size(dbsnp_vcf, "GB")) + 20

  command {
    java -Xmx2000m -jar /usr/gitc/picard.jar \
      CollectVariantCallingMetrics \
      INPUT=~{input_vcf} \
      OUTPUT=~{metrics_basename} \
      DBSNP=~{dbsnp_vcf} \
      SEQUENCE_DICTIONARY=~{ref_dict} \
      TARGET_INTERVALS=~{evaluation_interval_list} \
      GVCF_INPUT=true
  }
  runtime {
    docker: "us.gcr.io/broad-gotc-prod/genomes-in-the-cloud:2.4.1-1540490856"
    preemptible: preemptible_tries
    memory: "3 GB"
    disks: "local-disk " + disk_size + " HDD"
  }
  output {
    File summary_metrics = "~{metrics_basename}.variant_calling_summary_metrics"
    File detail_metrics = "~{metrics_basename}.variant_calling_detail_metrics"
  }
}
