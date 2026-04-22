#!/usr/bin/env python3

import argparse
import sys
import re
from pathlib import Path
import pandas as pd
from collections import defaultdict
from glob import glob

# Common FASTQ extensions to strip from the ID
FASTQ_SUFFIXES = [".fastq.gz", ".fq.gz", ".fastq", ".fq", ".gz"]

def strip_extensions(name: str) -> str:
    """Remove common extensions from the end of a filename."""
    res = name
    for _ in range(2):  # Handle double extensions like .fastq.gz
        for suf in FASTQ_SUFFIXES:
            if res.endswith(suf):
                res = res[:-len(suf)]
    return res

def main():
    parser = argparse.ArgumentParser(
        description="Generic file pairing using brace patterns with surgical ID extraction"
    )
    parser.add_argument(
        "pattern",
        help="Pattern with braces, e.g., 'path/to/*_R{1,2}_*.fastq.gz'"
    )
    parser.add_argument("-o", "--output", required=True, help="Output TSV file")
    args = parser.parse_args()

    # 1. Extract the options from the braces
    brace_match = re.search(r'\{([^}]+)\}', args.pattern)
    if not brace_match:
        sys.exit("ERROR: Pattern must contain braces with options, e.g., {1,2}")

    raw_brace_content = brace_match.group(0)
    options = brace_match.group(1).split(',')

    if len(options) != 2:
        sys.exit(f"ERROR: Braces must contain exactly 2 options. Found: {options}")

    # 2. Prepare Glob and Regex
    glob_pattern_str = args.pattern.replace(raw_brace_content, "*")

    # Escape pattern, then convert '*' back to capture groups
    regex_str = re.escape(args.pattern).replace(r'\*', '(.*)')
    tag_pattern = f"({re.escape(options[0])}|{re.escape(options[1])})"
    regex_str = regex_str.replace(re.escape(raw_brace_content), tag_pattern)

    pattern_re = re.compile(regex_str + "$")

    # 3. Find files
    path_obj = Path(glob_pattern_str)
    search_dir = path_obj.parent if path_obj.parent != Path('.') else Path('.')
    file_glob = path_obj.name

    files = list(Path("/").glob(glob_pattern_str.lstrip("/")))
    if not files:
        sys.exit(f"ERROR: No files found matching {glob_pattern_str}")

    # 4. Grouping Logic
    samples = defaultdict(dict)
    tag_group_index = pattern_re.groups # The {1,2} match is the last group

    for f in files:
        full_path = str(f)
        match = pattern_re.search(full_path)

        if match:
            read_tag = match.group(tag_group_index)

            # Get the character positions of the tag relative to the start of the string
            start, end = match.span(tag_group_index)

            # --- KEY FIX 1: Surgical Pairing Key ---
            # Mask ONLY the specific character index so R1 and R2 files share a key
            sample_key = full_path[:start] + "TAG" + full_path[end:]

            # --- KEY FIX 2: Surgical Sample ID ---
            # Remove the tag from the filename using its exact position, not a global replace
            # Then strip the extension
            fname = f.name
            # We need the position of the tag relative to the filename only
            tag_match_in_name = re.search(re.escape(read_tag), fname)
            # To be safest, we find where the tag is in the name by looking at the end of the full path
            rel_start = start - (len(full_path) - len(fname))
            rel_end = end - (len(full_path) - len(fname))

            # Remove the specific character at those indices
            id_stem = fname[:rel_start] + fname[rel_end:]
            clean_id = strip_extensions(id_stem).strip("._-")

            # Final cleanup of double delimiters (e.g. __ or ..)
            clean_id = clean_id.replace("__", "_").replace("..", ".")

            samples[sample_key]['id'] = clean_id
            samples[sample_key][read_tag] = str(f.resolve())

    # 5. Build Table
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
