#!/usr/bin/env python3
"""Helper script to format XML with proper indentation"""
import sys
import xml.dom.minidom as minidom

def format_xml_file(input_path, output_path):
    """Read XML, format it prettily, and write to output"""
    with open(input_path, 'r', encoding='utf-8') as f:
        xml_string = f.read()
    
    # Parse and format
    dom = minidom.parseString(xml_string)
    pretty_xml = dom.toprettyxml(indent="    ")
    
    # Remove extra blank lines and XML declaration
    lines = [line for line in pretty_xml.split('\n') if line.strip() and not line.strip().startswith('<?xml')]
    
    # Write formatted XML
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    
    return output_path

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python format_xml.py <input_file> <output_file>")
        sys.exit(1)
    
    format_xml_file(sys.argv[1], sys.argv[2])
    print(f"Formatted XML saved to: {sys.argv[2]}")
