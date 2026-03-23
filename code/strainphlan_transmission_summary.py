#!/usr/bin/env python3
import os
import csv

# Parse all transmission_events.info files
results = []

for info_file in "${transmission_files}".split():
    if not info_file.endswith('transmission_events.info'):
        continue
        
    # Extract SGB from parent directory name
    sgb = os.path.basename(os.path.dirname(info_file))
    
    with open(info_file, 'r') as f:
        lines = f.readlines()
        
        # Parse threshold
        threshold = None
        if len(lines) > 0 and 'threshold:' in lines[0]:
            threshold = lines[0].split(':')[1].strip()
        
        # Parse number of events
        n_events = None
        if len(lines) > 1 and 'Number of transmission events:' in lines[1]:
            n_events = lines[1].split(':')[1].strip()
        
        # Parse transmission pairs (skip header lines)
        pairs = []
        for line in lines[3:]:
            line = line.strip()
            if '<->' in line:
                pair = line.split(' <-> ')
                if len(pair) == 2:
                    pairs.append((pair[0], pair[1]))
        
        # Add to results
        for pair in pairs:
            results.append({
                'SGB': sgb,
                'Sample1': pair[0],
                'Sample2': pair[1],
                'Threshold': threshold,
                'Status': 'transmission_event'
            })
        
        # If no pairs, still record the SGB
        if len(pairs) == 0:
            results.append({
                'SGB': sgb,
                'Sample1': 'NA',
                'Sample2': 'NA',
                'Threshold': threshold,
                'Status': 'no_transmission'
            })

# Write summary CSV
with open('strainphlan_transmission_summary.csv', 'w', newline='') as csvfile:
    if len(results) > 0:
        writer = csv.DictWriter(csvfile, fieldnames=results[0].keys())
        writer.writeheader()
        writer.writerows(results)
    else:
        # Empty file with header only
        writer = csv.DictWriter(csvfile, fieldnames=['SGB', 'Sample1', 'Sample2', 'Threshold', 'Status'])
        writer.writeheader()

