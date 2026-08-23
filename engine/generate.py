#!/usr/bin/env python3
"""
Generate Terraform code from a validated resource request YAML.

Usage: python generate.py <request-file>
Outputs to: generated/<account>/<env>/<request-name>/
Prints OUTPUT_DIR=<path> to stdout for GitHub Actions step outputs.
All other status/info lines go to stderr so they don't pollute GITHUB_OUTPUT.
"""
import sys
import os
import re
import yaml
from jinja2 import Environment, FileSystemLoader

SCRIPT_DIR    = os.path.dirname(os.path.abspath(__file__))
TEMPLATES_DIR = os.path.join(SCRIPT_DIR, 'templates')
GENERATED_DIR = os.path.join(SCRIPT_DIR, '..', 'generated')
CATALOG_DIR   = os.path.join(SCRIPT_DIR, '..', 'catalog')


def load_catalog(resource_type):
    path = os.path.join(CATALOG_DIR, f'{resource_type.lower()}.yaml')
    with open(path) as f:
        return yaml.safe_load(f)


def normalize(name):
    return re.sub(r'[^a-z0-9-]', '-', str(name).lower()).strip('-')


def generate(request_file):
    with open(request_file) as f:
        req = yaml.safe_load(f)

    resource_type = req['resource_type'].upper()
    account       = normalize(req['account'])
    environment   = req['environment'].lower()
    request_name  = normalize(req['request_name'])
    region        = req.get('region', 'us-east-1')

    catalog  = load_catalog(resource_type)
    defaults = catalog.get('defaults', {})

    # EKS supported AZs for the requested region
    eks_azs = catalog.get('eks_supported_azs', {}).get(
        region,
        ['us-east-1a', 'us-east-1b', 'us-east-1c', 'us-east-1d', 'us-east-1f']
    )

    ctx = {
        # Identity
        'resource_type': resource_type,
        'request_name':  request_name,
        'account':       account,
        'environment':   environment,
        'region':        region,
        'project_name':  request_name,
        'issue_number':  req.get('issue_number', 0),
        # Network
        'vpc':    req.get('vpc', ''),
        'subnet': req.get('subnet', ''),
        # Module sources
        'module_source':    catalog['module_source'],
        'sg_module_source': catalog.get('sg_module_source', ''),
        # EC2 params
        'instance_type':    req.get('instance_type', defaults.get('instance_type', 't3.medium')),
        'public_access':    str(req.get('public_access', defaults.get('public_access', 'NO'))).upper(),
        'root_volume_size': int(req.get('root_volume_size', defaults.get('root_volume_size', 30))),
        # EKS params
        'kubernetes_version': str(req.get('kubernetes_version', defaults.get('kubernetes_version', '1.33'))),
        'node_count':         int(req.get('node_count', defaults.get('node_count', 2))),
        'min_nodes':          int(req.get('min_nodes', defaults.get('min_nodes', 1))),
        'max_nodes':          int(req.get('max_nodes', defaults.get('max_nodes', 5))),
        'eks_supported_azs':  eks_azs,
    }

    out_dir = os.path.join(GENERATED_DIR, account, environment, request_name)
    os.makedirs(out_dir, exist_ok=True)

    jenv = Environment(
        loader=FileSystemLoader(TEMPLATES_DIR),
        keep_trailing_newline=True,
        trim_blocks=True,
        lstrip_blocks=True,
    )

    templates = [
        ('backend.tf.j2',                  'backend.tf'),
        ('versions.tf.j2',                 'versions.tf'),
        ('data.tf.j2',                     'data.tf'),
        (f'{resource_type.lower()}.tf.j2', 'main.tf'),
        ('outputs.tf.j2',                  'outputs.tf'),
    ]

    for tmpl_name, out_name in templates:
        try:
            tmpl    = jenv.get_template(tmpl_name)
            content = tmpl.render(**ctx)
            out_path = os.path.join(out_dir, out_name)
            with open(out_path, 'w') as f:
                f.write(content)
            # Status goes to stderr — stdout is reserved for GITHUB_OUTPUT key=value pairs
            print(f"  Written: {out_path}", file=sys.stderr)
        except Exception as exc:
            print(f"  ERROR rendering {tmpl_name}: {exc}", file=sys.stderr)
            sys.exit(1)

    print(f"\n✅ Generated: {out_dir}", file=sys.stderr)
    # Only this line goes to stdout → GITHUB_OUTPUT
    print(f"OUTPUT_DIR={out_dir}")
    return out_dir


def main():
    if len(sys.argv) != 2:
        print("Usage: generate.py <request-file>", file=sys.stderr)
        sys.exit(1)
    generate(sys.argv[1])


if __name__ == '__main__':
    main()
