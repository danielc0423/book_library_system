#!/usr/bin/env python
"""
Quick fix script to add missing timestamp fields to fixture files.
"""
import json
import os
from datetime import datetime

def add_timestamps_to_books():
    """Add missing timestamp fields to books fixture."""
    filepath = '/Users/daniel/Desktop/book_library_system/backend/fixtures/books.json'
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    for i, book in enumerate(data):
        if 'created_date' not in book['fields']:
            # Add timestamps with slight variations
            base_time = f"2024-01-{15 + (i % 15):02d}T{10 + (i % 12):02d}:00:00Z"
            book['fields']['created_date'] = base_time
            book['fields']['updated_date'] = base_time
    
    with open(filepath, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"Updated {len(data)} books with timestamps")

def add_timestamps_to_borrowing_records():
    """Add missing timestamp fields to borrowing records fixture."""
    filepath = '/Users/daniel/Desktop/book_library_system/backend/fixtures/borrowing_records.json'
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    for i, record in enumerate(data):
        if 'created_at' not in record['fields']:
            # Use borrow_date as created_at, return_date or current as updated_at
            borrow_date = record['fields']['borrow_date']
            return_date = record['fields'].get('return_date') or borrow_date
            
            record['fields']['created_at'] = borrow_date
            record['fields']['updated_at'] = return_date
    
    with open(filepath, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"Updated {len(data)} borrowing records with timestamps")

if __name__ == '__main__':
    print("Adding missing timestamp fields to fixtures...")
    add_timestamps_to_books()
    add_timestamps_to_borrowing_records()
    print("Done!")
