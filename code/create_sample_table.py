#!/usr/bin/env python3

import argparse
import sys
import re
from pathlib import Path
import pandas as pd
from collections import defaultdict

FASTQ_SUFFIXES = [".fastq.gz", ".fq.gz", ".fastq", ".fq", ".gz"]

def strip_extensions(name: str) -> str:
    res = name
    for _ in range(2):
        for suf in FASTQ_SUFFIXES:
            if res.endswith(suf):
                res = res[:-len(suf)]
    return res

def main():
    parser = argparse.ArgumentParser(
        description="Generic file pairing using bracket patterns with surgical ID extraction"
    )
    parser.add_argument(
        "pattern",
        help="Pattern with brackets, e.g., 'path/to/*_R[12]_*.fastq.gz'"
    )
    parser.add_argument("-o", "--output", required=True, help="Output TSV file")
    args = parser.parse_args()

    # 1. Extract bracket content
    bracket_match = re.search(r'\[([^\]]+)\]', args.pattern)
    if not bracket_match:
        sys.exit("ERROR: Pattern must contain brackets, e.g., [12]")

    raw_bracket = bracket_match.group(0)
    options = list(bracket_match.group(1))

    if len(options) != 2:
        sys.exit(f"ERROR: Brackets must contain exactly 2 characters. Found: {options}")

    # 2. Prepare glob and regex
    glob_pattern_str = args.pattern.replace(raw_bracket, "*")

    regex_str = re.escape(args.pattern).replace(r'\*', '(.*)')

    # Replace bracket with regex capture group
    tag_pattern = f"([{''.join(map(re.escape, options))}])"
    regex_str = regex_str.replace(re.escape(raw_bracket), tag_pattern)

    pattern_re = re.compile(regex_str + "$")

    # 3. Find files
    files = list(Path("/").glob(glob_pattern_str.lstrip("/")))
    if not files:
        sys.exit(f"ERROR: No files found matching {glob_pattern_str}")

    # 4. Grouping
    samples = defaultdict(dict)
    tag_group_index = pattern_re.groups

    for f in files:
        full_path = str(f)
        match = pattern_re.search(full_path)

        if match:
            read_tag = match.group(tag_group_index)

            start, end = match.span(tag_group_index)

            sample_key = full_path[:start] + "TAG" + full_path[end:]

            fname = f.name
            rel_start = start - (len(full_path) - len(fname))
            rel_end = end - (len(full_path) - len(fname))

            id_stem = fname[:rel_start] + fname[rel_end:]
            clean_id = strip_extensions(id_stem).strip("._-")
            clean_id = clean_id.replace("__", "_").replace("..", ".")

            samples[sample_key]['id'] = clean_id
            samples[sample_key][read_tag] = str(f.resolve())

    # 5. Build table
    rows = []
    opt1, opt2 = options

    for key, data in samples.items():
        if opt1 in data and opt2 in data:
            rows.append({
                "sample_id": data['id'],
                "read1": data[opt1],
                "read2": data[opt2]
            })

    if not rows:
        sys.exit("ERROR: No complete pairs found. Check your pattern.")

    df = pd.DataFrame(rows)[["sample_id", "read1", "read2"]]
    df.to_csv(args.output, sep="\t", index=False)

    print(f"Success! Created {args.output} with {len(rows)} pairs.")

if __name__ == "__main__":
    main()
