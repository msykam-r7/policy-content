"""
Generate XCCDF Report Library
Builds XCCDF XML payloads from JSON templates for report generation API requests
"""
import json
from typing import Dict, Any


class XCCDFReportGenerator:
    """Build XML request payloads for report generation from JSON templates"""
    
    @staticmethod
    def build_xccdf_report_xml(json_payload: Dict[str, Any]) -> str:
        """
        Build XCCDF report XML from JSON payload
        
        Args:
            json_payload: Dictionary containing report configuration
            
        Returns:
            XML string for ReportSaveRequest
        """
        session_id = json_payload.get('session_id', '')
        generate_now = json_payload.get('generate_now', '1')
        
        config = json_payload.get('report_config', {})
        config_id = config.get('id', '-1')
        config_format = config.get('format', 'xccdf-xml')
        config_name = config.get('name', '')
        
        filters = config.get('filters', {})
        site_id = filters.get('site_id', '')
        policy_id = filters.get('policy_natural_id', '')
        
        generate = config.get('generate', {})
        after_scan = generate.get('after_scan', '0')
        schedule = generate.get('schedule', '0')
        
        delivery = config.get('delivery', {})
        store_on_server = delivery.get('store_on_server', '1')
        
        xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<ReportSaveRequest session-id="{session_id}" generate-now="{generate_now}">
<ReportConfig id="{config_id}" format="{config_format}" name="{config_name}">
<Filters>
<filter type="site" id="{site_id}">{site_id}</filter>
<filter type="policy-listing" id="{policy_id}">{policy_id}</filter>
</Filters>
<Generate after-scan="{after_scan}" schedule="{schedule}"/>
<Delivery>
<Storage storeOnServer="{store_on_server}"/>
</Delivery>
</ReportConfig>
</ReportSaveRequest>'''
        
        return xml
    
    @staticmethod
    def load_and_build_xccdf_report(
        json_file_path: str,
        session_id: str,
        site_id: str,
        policy_natural_id: str,
        report_name: str
    ) -> str:
        """
        Load JSON template and build XCCDF report XML with parameters
        
        Args:
            json_file_path: Path to JSON template file
            session_id: Nexpose session ID
            site_id: Site ID for filtering
            policy_natural_id: Policy natural ID for filtering
            report_name: Name for the report
            
        Returns:
            XML string for ReportSaveRequest
        """
        with open(json_file_path, 'r') as f:
            payload = json.load(f)
        
        # Update payload with parameters
        payload['session_id'] = session_id
        payload['report_config']['name'] = report_name
        payload['report_config']['filters']['site_id'] = site_id
        payload['report_config']['filters']['policy_natural_id'] = policy_natural_id
        
        return XCCDFReportGenerator.build_xccdf_report_xml(payload)
