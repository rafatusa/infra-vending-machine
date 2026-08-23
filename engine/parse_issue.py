#!/usr/bin/env python3
"""
Parse a GitHub Issue Form body into a request YAML file.

Usage: python parse_issue.py <issue_number> <requests_dir>
  Reads ISSUE_BODY from environment variable.
  Writes to <requests_dir>/<account>/<env>/<request_name>.yaml
  Prints key=value lines to stdout for GitHub Actions step outputs.
"""
import sys
import os
import re
import yaml

# Maps the GitHub Issue Form heading text (lowercased) to request YAML keys
FIELD_MAP = {
    "request name": "request_name",
    "udap action": "udap_action",
    "resource type": "resource_type",
    "environment": "environment",
    "aws account / subscription": "account",
    "aws account": "account",
    "region": "region",
    "vpc (tag:name)": "vpc",
    "vpc": "vpc",
    "subnet (tag:name)": "subnet",
    "subnet": "subnet",
    "instance type": "instance_type",
    "public access required": "public_access",
    "business / application name": "business_name",
    "business justification": "justification",
    "kubernetes version": "kubernetes_version",
    "node count": "node_count",
}


def parse_body(body):
    """Parse GitHub Issue Form body (### Heading / value blocks) into dict."""
    result = {}
    # Prepend newline so first heading matches the split pattern
    sections = re.split(r'\n###\s+', '\n' + body)
    for section in sections:
        if not section.strip():
            continue
        lines = section.split('\n')
        header = lines[0].strip().lower()
        value = '\n'.join(lines[1:]).strip()
        if not value or value in ('_No response_', 'None', 'none', ''):
            continue
        key = FIELD_MAP.get(header)
        if key:
            result[key] = value
    return result


def normalize(name):
    """Lowercase, replace non-alnum chars with hyphens, strip edge hyphens."""
    return re.sub(r'[^a-z0-9-]', '-', str(name).lower()).strip('-')


def main():
    if len(sys.argv) < 3:
        print("Usage: parse_issue.py <issue_number> <requests_dir>", file=sys.stderr)
        sys.exit(1)

    issue_number = sys.argv[1]
    requests_dir = sys.argv[2]

    body = os.environ.get('ISSUE_BODY', '')
    if not body:
        print("ERROR: ISSUE_BODY env var is empty", file=sys.stderr)
        sys.exit(1)

    parsed = parse_body(body)

    request_name = normalize(parsed.get('request_name', f'request-{issue_number}'))
    account      = normalize(parsed.get('account', 'unknown-account'))
    environment  = parsed.get('environment', 'DEV').lower()
    udap_action  = parsed.get('udap_action', 'PLAN_ONLY').strip()
    resource_type = parsed.get('resource_type', 'EC2').upper().strip()

    request = {
        'request_name':  request_name,
        'issue_number':  int(issue_number),
        'udap_action':   udap_action,
        'resource_type': resource_type,
        'environment':   environment,
        'account':       account,
        'region':        parsed.get('region', 'us-east-1').strip(),
        'vpc':           parsed.get('vpc', '').strip(),
        'subnet':        parsed.get('subnet', '').strip(),
        'business_name': parsed.get('business_name', '').strip(),
        'justification': parsed.get('justification', '').strip(),
    }

    if resource_type == 'EC2':
        request['instance_type'] = parsed.get('instance_type', 't3.medium').strip()
        request['public_access']  = parsed.get('public_access', 'NO').strip()

    elif resource_type == 'EKS':
        request['kubernetes_version'] = parsed.get('kubernetes_version', '1.33').strip()
        request['node_count']         = int(parsed.get('node_count', 2))
        request['instance_type']      = parsed.get('instance_type', 't3.medium').strip()

    # Write request YAML to requests/<account>/<env>/<name>.yaml
    req_dir  = os.path.join(requests_dir, account, environment)
    os.makedirs(req_dir, exist_ok=True)
    req_file = os.path.join(req_dir, f'{request_name}.yaml')
    with open(req_file, 'w') as f:
        yaml.dump(request, f, default_flow_style=False, sort_keys=False)

    # Emit key=value pairs for GitHub Actions $GITHUB_OUTPUT
    print(f"REQUEST_FILE={req_file}")
    print(f"REQUEST_NAME={request_name}")
    print(f"UDAP_ACTION={udap_action}")
    print(f"ACCOUNT={account}")
    print(f"ENVIRONMENT={environment}")
    print(f"RESOURCE_TYPE={resource_type}")


if __name__ == '__main__':
    main()
