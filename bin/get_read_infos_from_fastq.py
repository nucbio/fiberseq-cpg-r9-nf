#!/usr/bin/env python3
# Python 3 port of npd26/tools/get_read_infos_from_fastq.py
# Parses guppy headers as key=value tokens, e.g.
# @<read_id> runid=... sampleid=... read=2030 ch=417 start_time=... model_version_id=... barcode=barcode01
import argparse

parser = argparse.ArgumentParser(description='Returns read infos from fastq file')
parser.add_argument('-i', '--input', type=str, required=True)
parser.add_argument('-c', '--barcode_input', type=str, required=False, default='NA')
args = parser.parse_args()

print('\t'.join(['read_name', 'read_num_in_channel', 'channel', 'start_time', 'barcode']))
with open(args.input) as fastq_file:
    for i, ln in enumerate(fastq_file):
        if i % 4 != 0:  # header is the first line of every 4-line record
            continue
        tokens = ln[1:].split()
        fields = dict(t.split('=', 1) for t in tokens[1:] if '=' in t)
        print('\t'.join([tokens[0], fields.get('read', 'NA'), fields.get('ch', 'NA'),
                         fields.get('start_time', 'NA'), fields.get('barcode', args.barcode_input)]))
