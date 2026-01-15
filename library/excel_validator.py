"""
Excel-based XCCDF Report Validator
Reads rules from Excel/CSV and validates against XCCDF XML reports
"""

import csv
import openpyxl
from pathlib import Path
from xml.etree import ElementTree as ET
from typing import List, Dict, Tuple


class ExcelValidator:
    """Validates XCCDF reports against rules defined in Excel/CSV files"""
    
    # Result mapping from XCCDF to human-readable format
    RESULT_MAPPING = {
        'pass': 'COMPLIANT',
        'fail': 'NOT COMPLIANT',
        'notapplicable': 'NOT APPLICABLE',
        'notchecked': 'NOT CHECKED',
        'notselected': 'NOT SELECTED',
        'informational': 'INFORMATIONAL',
        'error': 'ERROR',
        'unknown': 'UNKNOWN',
        'fixed': 'FIXED'
    }
    
    def __init__(self):
        """Initialize the validator"""
        self.rules = []
        self.all_rules = []  # Store all rules before filtering
        self.validation_results = []
    
    def load_rules_from_csv(self, csv_path: str, profile_filter: str = None) -> List[Dict]:
        """
        Load validation rules from CSV file
        
        Expected CSV format:
        NUMBER,RULE_ID,EXPECTED_RESULT,PROFILE
        1,xccdf_org...,COMPLIANT,SEVERITY_CAT_I
        
        Args:
            csv_path: Path to CSV file
            profile_filter: Optional profile name to filter rules (e.g., 'SEVERITY_CAT_I')
            
        Returns:
            List of rule dictionaries
        """
        rules = []
        csv_file = Path(csv_path)
        
        if not csv_file.exists():
            raise FileNotFoundError(f"CSV file not found: {csv_path}")
        
        with open(csv_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                rule = {
                    'number': int(row['NUMBER']),
                    'rule_id': row['RULE_ID'].strip(),
                    'expected_result': row['EXPECTED_RESULT'].strip().upper(),
                    'description': row.get('DESCRIPTION', '').strip(),
                    'profile': row.get('PROFILE', '').strip()
                }
                
                # Filter by profile if specified
                if profile_filter is None or rule['profile'].upper() == profile_filter.upper():
                    rules.append(rule)
        
        self.all_rules = rules if profile_filter is None else self.all_rules
        self.rules = rules
        return rules
    
    def load_rules_from_excel(self, excel_path: str, sheet_name: str = None, profile_filter: str = None) -> List[Dict]:
        """
        Load validation rules from Excel file
        
        Expected Excel format (same as CSV):
        NUMBER | RULE_ID | EXPECTED_RESULT | PROFILE
        1      | xccdf... | COMPLIANT      | SEVERITY_CAT_I
        
        Args:
            excel_path: Path to Excel file (.xlsx)
            sheet_name: Sheet name (if None, uses first sheet)
            profile_filter: Optional profile name to filter rules (e.g., 'SEVERITY_CAT_I')
            
        Returns:
            List of rule dictionaries
        """
        rules = []
        excel_file = Path(excel_path)
        
        if not excel_file.exists():
            raise FileNotFoundError(f"Excel file not found: {excel_path}")
        
        workbook = openpyxl.load_workbook(excel_file, read_only=True)
        sheet = workbook[sheet_name] if sheet_name else workbook.active
        
        # Read header row
        headers = []
        for cell in sheet[1]:
            headers.append(cell.value)
        
        # Validate headers
        required_headers = ['NUMBER', 'RULE_ID', 'EXPECTED_RESULT']
        for header in required_headers:
            if header not in headers:
                raise ValueError(f"Missing required header: {header}")
        
        # Read data rows
        for row in sheet.iter_rows(min_row=2, values_only=True):
            if not row[0]:  # Skip empty rows
                continue
            
            rule_data = dict(zip(headers, row))
            rule = {
                'number': int(rule_data['NUMBER']),
                'rule_id': str(rule_data['RULE_ID']).strip(),
                'expected_result': str(rule_data['EXPECTED_RESULT']).strip().upper(),
                'description': str(rule_data.get('DESCRIPTION', '')).strip(),
                'profile': str(rule_data.get('PROFILE', '')).strip()
            }
            
            # Filter by profile if specified
            if profile_filter is None or rule['profile'].upper() == profile_filter.upper():
                rules.append(rule)
        
        workbook.close()
        self.all_rules = rules if profile_filter is None else self.all_rules
        self.rules = rules
        return rules
    
    def validate_xccdf_report(self, xml_content: str) -> Tuple[int, int, List[Dict]]:
        """
        Validate XCCDF report against loaded rules
        
        Args:
            xml_content: XCCDF XML report content as string
            
        Returns:
            Tuple of (passed_count, failed_count, results_list)
        """
        if not self.rules:
            raise ValueError("No rules loaded. Call load_rules_from_csv() or load_rules_from_excel() first.")
        
        # Parse XML
        root = ET.fromstring(xml_content)
        
        passed = 0
        failed = 0
        results = []
        
        # Validate each rule
        for rule in self.rules:
            rule_id = rule['rule_id']
            expected = rule['expected_result']
            
            # Find rule-result element using XPath
            rule_result = root.find(f".//{{*}}rule-result[@idref='{rule_id}']")
            
            if rule_result is None:
                # Rule not found in report
                result = {
                    'number': rule['number'],
                    'rule_id': rule_id,
                    'description': rule['description'],
                    'expected': expected,
                    'actual': 'NOT FOUND',
                    'status': 'FAIL',
                    'message': f"Rule not found in XCCDF report"
                }
                failed += 1
            else:
                # Get actual result
                result_elem = rule_result.find('.//{*}result')
                if result_elem is None:
                    actual_result = 'UNKNOWN'
                else:
                    xccdf_result = result_elem.text.lower()
                    actual_result = self.RESULT_MAPPING.get(xccdf_result, xccdf_result.upper())
                
                # Compare expected vs actual
                if actual_result == expected:
                    status = 'PASS'
                    passed += 1
                    message = '✓ Match'
                else:
                    status = 'FAIL'
                    failed += 1
                    message = f'✗ Mismatch: Expected {expected}, Got {actual_result}'
                
                result = {
                    'number': rule['number'],
                    'rule_id': rule_id,
                    'description': rule['description'],
                    'expected': expected,
                    'actual': actual_result,
                    'status': status,
                    'message': message
                }
            
            results.append(result)
        
        self.validation_results = results
        return passed, failed, results
    
    def get_validation_summary(self) -> str:
        """
        Get formatted summary of validation results
        
        Returns:
            Formatted string with validation summary
        """
        if not self.validation_results:
            return "No validation results available"
        
        total = len(self.validation_results)
        passed = sum(1 for r in self.validation_results if r['status'] == 'PASS')
        failed = total - passed
        
        summary = f"\n{'='*80}\n"
        summary += f"VALIDATION SUMMARY\n"
        summary += f"{'='*80}\n"
        summary += f"Total Rules: {total}\n"
        summary += f"Passed: {passed} ✓\n"
        summary += f"Failed: {failed} ✗\n"
        summary += f"Success Rate: {(passed/total*100):.1f}%\n"
        summary += f"{'='*80}\n\n"
        
        # Detailed results table
        summary += f"{'#':<4} | {'STATUS':<6} | {'EXPECTED':<15} | {'ACTUAL':<15} | {'DESCRIPTION':<30}\n"
        summary += f"{'-'*4}-+-{'-'*6}-+-{'-'*15}-+-{'-'*15}-+-{'-'*30}\n"
        
        for result in self.validation_results:
            num = str(result['number'])
            status = result['status']
            expected = result['expected']
            actual = result['actual']
            desc = result['description'][:30]  # Truncate long descriptions
            
            summary += f"{num:<4} | {status:<6} | {expected:<15} | {actual:<15} | {desc:<30}\n"
        
        summary += f"{'='*80}\n"
        
        return summary
    
    def get_failed_rules(self) -> List[Dict]:
        """Get list of failed rules only"""
        return [r for r in self.validation_results if r['status'] == 'FAIL']
    
    def get_passed_rules(self) -> List[Dict]:
        """Get list of passed rules only"""
        return [r for r in self.validation_results if r['status'] == 'PASS']
