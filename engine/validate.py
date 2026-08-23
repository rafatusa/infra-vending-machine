#!/usr/bin/env python3
"""
Validate a resource request YAML against the catalog schema.

Usage: python validate.py <request-file>
Exit 0 = valid, exit 1 = invalid (errors printed to stderr).
"""
import sys
import os
import yaml

CATALOG_DIR    = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'catalog')
VALID_ACTIONS  = {'VALIDATE_AND_EXECUTE', 'PLAN_ONLY', 'DESTROY'}
VALID_TYPES    = {'EC2', 'EKS'}
BASE_REQUIRED  = ['request_name', 'udap_action', 'resource_type', 'environment', 'account', 'region', 'vpc']


def load_catalog(resource_type):
    path = os.path.join(CATALOG_DIR, f'{resource_type.lower()}.yaml')
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return yaml.safe_load(f)


def validate(request_file):
    errors = []

    with open(request_file) as f:
        req = yaml.safe_load(f)

    # Base required fields
    for field in BASE_REQUIRED:
        if not req.get(field):
            errors.append(f"Missing required field: {field}")
    if errors:
        return errors

    # UDAP action
    action = req['udap_action'].strip()
    if action not in VALID_ACTIONS:
        errors.append(f"Invalid udap_action '{action}'. Must be one of: {sorted(VALID_ACTIONS)}")

    # Resource type
    rtype = req['resource_type'].upper().strip()
    if rtype not in VALID_TYPES:
        errors.append(f"Invalid resource_type '{rtype}'. Supported: {sorted(VALID_TYPES)}")
        return errors

    catalog = load_catalog(rtype)
    if not catalog:
        errors.append(f"No catalog entry for resource type: {rtype}")
        return errors

    # Environment
    env = req['environment'].upper()
    allowed_envs = catalog.get('allowed_environments', [])
    if allowed_envs and env not in allowed_envs:
        errors.append(f"Invalid environment '{env}'. Allowed: {allowed_envs}")

    # Instance type (EC2 + EKS node)
    instance_type  = req.get('instance_type', '').strip()
    allowed_types  = catalog.get('allowed_instance_types', [])
    if instance_type and allowed_types and instance_type not in allowed_types:
        errors.append(f"Invalid instance_type '{instance_type}'. Allowed: {allowed_types}")

    # EC2-specific
    if rtype == 'EC2' and not req.get('subnet'):
        errors.append("EC2 requests require a 'subnet' field (tag:Name of the target subnet)")

    return errors


def main():
    if len(sys.argv) != 2:
        print("Usage: validate.py <request-file>", file=sys.stderr)
        sys.exit(1)

    errors = validate(sys.argv[1])
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    print("✅ Request validation passed")
    sys.exit(0)


if __name__ == '__main__':
    main()
