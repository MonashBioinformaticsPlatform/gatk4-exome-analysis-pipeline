# gatk4-exome-analysis-pipeline
### Purpose :
This WDL pipeline implements data pre-processing and initial variant calling according to the GATK Best Practices for germline SNP and Indel discovery in human exome sequencing data.

### Requirements/expectations :
- Human exome sequencing data in unmapped BAM (uBAM) format
- One or more read groups, one per uBAM file, all belonging to a single sample (SM)
- Input uBAM files must additionally comply with the following requirements:
- - filenames all have the same suffix (we use ".unmapped.bam")
- - files must pass validation by ValidateSamFile
- - reads are provided in query-sorted order
- - all reads must have an RG tag
- GVCF output names must end in ".g.vcf.gz"
- Reference genome must be Hg38 with ALT contigs
- Unique exome calling, target, and bait [.interval_list](https://software.broadinstitute.org/gatk/documentation/article?id=11009) obtained from sequencing provider. Generally the calling, target, and bait files will not be the same.

### Output :
- Cram, cram index, and cram md5
- GVCF and its gvcf index
- BQSR Report
- Several Summary Metrics

### Installing the workflow and cromwell
```sh
git clone --recursive https://github.com/MonashBioinformaticsPlatform/gatk4-exome-analysis-pipeline.git
# Create a conda environment called 'cromwell', and install cromwell into it
conda create -n cromwell -c bioconda -c conda-forge cromwell
conda activate cromwell
pip install gsutil
pip install j2cli
```

### Getting the references and example data
```sh
export REF_BASE=/scratch/pl41/references
mkdir -p $REF_BASE/references/broad-references/
cd $REF_BASE/references/broad-references/
gsutil -m rsync -r -x "CrossSpeciesContamination/*" gs://broad-references/hg38 hg38
```

```sh
mkdir -p $REF_BASE/references/gatk-best-practices/exome-analysis-pipeline
cd $REF_BASE/references/gatk-best-practices/exome-analysis-pipeline
gsutil -m cp gs://gatk-best-practices/exome-analysis-pipeline/SRR099969.unmapped.bam SRR099969.unmapped.bam .
# wget https://storage.googleapis.com/gatk-best-practices/exome-analysis-pipeline/SRR099969.unmapped.bam
```

### Running (example)

Generate `inputs.json` and `options.json` files based on the template:
```sh
export REF_BASE=/scratch/pl41/references
export SLURM_ACCOUNT=pl41
export SINGULARITY_CACHE=/scratch/${SLURM_ACCOUNT}/singularity_cache
export SINGULARITY_BIND_PATH=/scratch
export TMPDIR=/scratch/${SLURM_ACCOUNT}/tmp

j2 gatk4-exome-analysis-pipeline/ExomeGermlineSingleSample.inputs.json.j2 \
   >gatk4-exome-analysis-pipeline/ExomeGermlineSingleSample.inputs.json

j2 gatk4-exome-analysis-pipeline/ExomeGermlineSingleSample.options.json.j2 \
   >gatk4-exome-analysis-pipeline/ExomeGermlineSingleSample.options.json
```

Run the pipeline:
```sh
cromwell -Xmx8g \
         -Dconfig.file=$(pwd)/gatk4-exome-analysis-pipeline/slurm-backend.conf \
         -Dsystem.input-read-limits.lines=1000000 \
         -Ddefault_runtime_attributes.tmp=$TMPDIR \
         -Ddefault_runtime_attributes.singularity_cache=$SINGULARITY_CACHE \
         -Ddefault_runtime_attributes.singularity_bind_path=$SINGULARITY_BIND_PATH \
         -Ddefault_runtime_attributes.slurm_account=$SLURM_ACCOUNT \
         run gatk4-exome-analysis-pipeline/ExomeGermlineSingleSample.wdl \
         --inputs gatk4-exome-analysis-pipeline/ExomeGermlineSingleSample.inputs.json \
         --options gatk4-exome-analysis-pipeline/ExomeGermlineSingleSample.options.json
```

### Software version notes :
- GATK 4 or later 
- Cromwell version support 
  - Successfully tested on v36 
  - Does not work on versions < v23 due to output syntax

### Important Note :
- Runtime parameters are optimized for Broad's Google Cloud Platform implementation.
- For help running workflows on the Google Cloud Platform or locally please
view the following tutorial [(How to) Execute Workflows from the gatk-workflows Git Organization](https://software.broadinstitute.org/gatk/documentation/article?id=12521).
- The following material is provided by the GATK Team. Please post any questions or concerns to one of our forum sites : [GATK](https://gatkforums.broadinstitute.org/gatk/categories/ask-the-team/) , [FireCloud](https://gatkforums.broadinstitute.org/firecloud/categories/ask-the-firecloud-team) , [WDL/Cromwell](https://gatkforums.broadinstitute.org/wdl/categories/ask-the-wdl-team).
- Please visit the [User Guide](https://software.broadinstitute.org/gatk/documentation/) site for further documentation on our workflows and tools.

### LICENSING :
Copyright Broad Institute, 2018 | BSD-3

This script is released under the WDL open source code license (BSD-3) (full license text at https://github.com/openwdl/wdl/blob/master/LICENSE). Note however that the programs it calls may be subject to different licenses. Users are responsible for checking that they are authorized to run all programs before running this script.
