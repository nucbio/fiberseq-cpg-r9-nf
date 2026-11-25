#!/usr/bin/env python3
# Python 3 port of npd26/tools/get_read_infos_from_bam.py
import argparse
import pysam
import numpy as np

parser = argparse.ArgumentParser(description='Returns read infos from input bam file')
parser.add_argument('-i', '--input', type=str, required=True)
args = parser.parse_args()

header = ['read_name', 'ref_seq', 'strand', 'reference_start', 'aligned_reference_length',
          'aligned_query_length', 'length_incl_softclipping', 'length_incl_hardclipping',
          'mapping_quality', 'quality_average', 'quality_std', 'quality_min', 'quality_perc_25',
          'quality_median', 'quality_perc_75', 'quality_max']
print('\t'.join(header))

with pysam.AlignmentFile(args.input, 'rb') as samfile:
    for read in samfile.fetch():
        try:
            s1 = [read.query_name, read.reference_name, '-' if read.is_reverse else '+',
                  read.reference_start, read.reference_length, read.query_alignment_length,
                  read.query_length, read.infer_read_length(), read.mapping_quality]
        except TypeError:
            s1 = [read.query_name] + ['NaN'] * 8
        try:
            q = np.array(read.query_alignment_qualities)  # basecall qualities of the aligned part
            s2 = [q.mean(), q.std(), q.min(), np.percentile(q, 25), np.median(q),
                  np.percentile(q, 75), q.max()]
        except (TypeError, ValueError):
            s2 = ['NaN'] * 7
        print('\t'.join(str(x) for x in s1 + s2))
