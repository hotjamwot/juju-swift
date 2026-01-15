#!/usr/bin/env python3
import csv
import os
import sys
from pathlib import Path

def clean_csv_file_content(file_path):
    """
    Reads a file, strips leading empty lines, and returns the cleaned content
    and the number of leading empty lines removed.
    """
    leading_empty_lines = 0
    with open(file_path, 'r', newline='', encoding='utf-8') as f_in:
        lines = f_in.readlines()
        # Find the first non-empty line
        for i, line in enumerate(lines):
            if line.strip(): # If line is not empty or just whitespace
                leading_empty_lines = i
                break
        else: # All lines were empty
            leading_empty_lines = len(lines)
            return [], leading_empty_lines
    
    cleaned_lines = lines[leading_empty_lines:]
    return cleaned_lines, leading_empty_lines

def migrate_sessions(data_path):
    """Migrate milestoneText to action + isMilestone in CSV files"""
    # Ensure data_path is a Path object
    data_path = Path(data_path)

    # Find all CSV files in the directory that match the pattern *-data.csv
    csv_files = list(data_path.glob('*-data.csv'))
    if not csv_files:
        print(f"No CSV files matching '*-data.csv' found in {data_path}")
        # Also try to find any .csv files if the specific pattern doesn't match
        all_csv_files = list(data_path.glob('*.csv'))
        if all_csv_files:
            print(f"Found other CSV files: {[f.name for f in all_csv_files]}")
        return

    print(f"Found {len(csv_files)} CSV files to process: {[f.name for f in csv_files]}")

    for csv_file in csv_files:
        print(f"\nProcessing {csv_file.name}...")

        try:
            # Step 1: Clean the file content and get actual data lines
            cleaned_lines, leading_empty_lines = clean_csv_file_content(csv_file)

            if not cleaned_lines:
                print(f"No data or only empty lines in {csv_file.name}, skipping")
                continue
            
            if leading_empty_lines > 0:
                print(f"  Found and will skip {leading_empty_lines} leading empty line(s) in {csv_file.name}.")

            # Step 2: Use csv.reader to get the header from the first data line
            # This helps if DictReader was confused by leading empty lines
            temp_header_reader = csv.reader(cleaned_lines)
            try:
                original_header_row = next(temp_header_reader)
            except StopIteration:
                print(f"No header found in {csv_file.name} after cleaning, skipping.")
                continue
            
            # Check if migration already done by looking for new columns
            if 'action' in original_header_row and 'is_milestone' in original_header_row:
                print(f"Migration already completed for {csv_file.name} (new columns found in header), skipping")
                continue
            
            updated_fieldnames = original_header_row.copy()
            updated_fieldnames.append('action')
            updated_fieldnames.append('is_milestone')

            # Step 3: Process data rows using DictReader with the confirmed header
            # The cleaned_lines already has the header at index 0
            # So, DictReader should work correctly now.
            # We need to provide the corrected lines to DictReader.
            # csv.DictReader expects an iterable of lines.
            dict_reader_lines = cleaned_lines # These are the lines after potential leading empty lines
            
            migrated_rows = []
            # Skip the header line for DictReader if we are providing it explicitly
            # Or, let DictReader read the first line as header.
            # Let's use the original_header_row to ensure consistency.
            
            # Re-create the cleaned_lines as a string for DictReader to consume from the start
            # This is safer as DictReader will read its own header.
            with open(csv_file, 'r', newline='', encoding='utf-8') as f_for_dict_reader:
                # Pass only the relevant part of the file to DictReader
                # We need to seek to the beginning of the actual data content.
                f_for_dict_reader.seek(0) # Go back to start
                # Skip leading empty lines again for this new read
                for _ in range(leading_empty_lines):
                    next(f_for_dict_reader)
                
                reader = csv.DictReader(f_for_dict_reader, fieldnames=original_header_row) # Provide known header
                rows_to_process = list(reader)


            if not rows_to_process:
                print(f"No data rows to process in {csv_file.name} after header, skipping.")
                continue

            for row_idx, row in enumerate(rows_to_process):
                # Get milestone_text value (case-insensitive search for key)
                milestone_text = None
                for key in row.keys():
                    if key.lower() == 'milestone_text':
                        milestone_text = row[key]
                        break
                
                new_row = row.copy()
                if milestone_text and milestone_text.strip(): 
                    new_row['action'] = milestone_text.strip()
                    new_row['is_milestone'] = '1'
                else:
                    new_row['action'] = ''
                    new_row['is_milestone'] = '0'
                
                migrated_rows.append(new_row)
                if (row_idx + 1) % 100 == 0: 
                    print(f"  Processed {row_idx + 1}/{len(rows_to_process)} rows in {csv_file.name}")

            # Step 4: Write back to file with the new header and migrated data
            with open(csv_file, 'w', newline='', encoding='utf-8') as f_out:
                writer = csv.DictWriter(f_out, fieldnames=updated_fieldnames)
                writer.writeheader()
                writer.writerows(migrated_rows)

            print(f"Successfully migrated {len(migrated_rows)} sessions in {csv_file.name}")

        except Exception as e:
            print(f"Error processing {csv_file.name}: {str(e)}")
            import traceback
            traceback.print_exc() # Print full traceback for debugging
            continue

    print("\nMigration processing complete for all found files.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python migrate_sessions.py <data_path>")
        print("Example: python migrate_sessions.py ~/Library/Application\\ Support/Juju/")
        sys.exit(1)

    data_path_str = sys.argv[1]
    
    if data_path_str.startswith('~'):
        data_path_str = os.path.expanduser(data_path_str)

    if not os.path.isdir(data_path_str):
        print(f"Error: '{data_path_str}' is not a valid directory")
        sys.exit(1)

    print(f"Starting migration for data in: {data_path_str}")
    migrate_sessions(data_path_str)
    print("\nOverall migration script finished.")
