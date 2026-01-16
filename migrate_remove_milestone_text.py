#!/usr/bin/env python3
"""
Remove milestone_text column from all CSV files in the Juju data directory.
This script handles CSV files with quoted fields and embedded newlines properly.
"""

import csv
import os
from pathlib import Path

# Target directory
JUJU_DATA_DIR = Path.home() / "Library" / "Application Support" / "juju"

def migrate_csv_file(file_path):
    """
    Remove milestone_text column from a CSV file.
    Preserves all other columns and data integrity.
    """
    print(f"Processing: {file_path.name}")
    
    try:
        # Read the CSV file
        with open(file_path, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            rows = list(reader)
        
        if not rows:
            print(f"  ⚠️  File is empty, skipping")
            return False
        
        # Get header
        header = rows[0]
        
        # Find milestone_text column index
        if 'milestone_text' not in header:
            print(f"  ℹ️  No milestone_text column found, skipping")
            return False
        
        milestone_text_idx = header.index('milestone_text')
        print(f"  Found milestone_text at column index {milestone_text_idx}")
        
        # Create new header without milestone_text
        new_header = header[:milestone_text_idx] + header[milestone_text_idx+1:]
        
        # Create new rows without milestone_text column
        new_rows = [new_header]
        for row in rows[1:]:
            # Handle case where row might be shorter than header
            if len(row) > milestone_text_idx:
                new_row = row[:milestone_text_idx] + row[milestone_text_idx+1:]
            else:
                new_row = row
            new_rows.append(new_row)
        
        # Write back to file
        with open(file_path, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f)
            writer.writerows(new_rows)
        
        print(f"  ✅ Successfully migrated ({len(new_rows)-1} data rows)")
        
        # Print new header for verification
        print(f"  New header: {','.join(new_header)}")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Error processing file: {e}")
        return False

def main():
    print("🔄 Starting migration: Remove milestone_text column\n")
    
    if not JUJU_DATA_DIR.exists():
        print(f"❌ Juju data directory not found: {JUJU_DATA_DIR}")
        return
    
    # Find all CSV files
    csv_files = list(JUJU_DATA_DIR.glob("*-data.csv"))
    
    if not csv_files:
        print(f"❌ No CSV files found in {JUJU_DATA_DIR}")
        return
    
    print(f"Found {len(csv_files)} CSV file(s):\n")
    
    successful = 0
    for csv_file in sorted(csv_files):
        if migrate_csv_file(csv_file):
            successful += 1
        print()
    
    print(f"{'='*60}")
    print(f"✅ Migration complete: {successful}/{len(csv_files)} files processed")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
