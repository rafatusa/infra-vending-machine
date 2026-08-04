// Pulumi EC2 vending machine — infra-vending-machine
//
// Toggle: set PULUMI_CREATE_EC2=true in the pipeline env to provision the EC2.
// Default is false — a bare run is always a no-op (preview only).
//
// Module source: github.com/rafatusa/enterprise-infra-module/pulumi v1.1.0
//   Components used:
//     - pulumi/modules/aws/security-group  → NewSecurityGroup
//     - pulumi/modules/aws/ec2             → NewInstance
//
// State backend: Pulumi Cloud (PULUMI_ACCESS_TOKEN secret required)
// Stack:         prod  (Pulumi.prod.yaml sets aws:region = us-east-1)

package main

import (
	"os"

	"github.com/pulumi/pulumi-aws/sdk/v6/go/aws/ec2"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi/config"

	pulumiEC2 "github.com/rafatusa/enterprise-infra-module/pulumi/modules/aws/ec2"
	pulumiSG  "github.com/rafatusa/enterprise-infra-module/pulumi/modules/aws/security-group"
)

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		cfg := config.New(ctx, "")

		// ---------------------------------------------------------------
		// Toggle — set PULUMI_CREATE_EC2=true to provision.
		// A bare push/preview is always a no-op when this is false.
		// ---------------------------------------------------------------
		createEC2 := os.Getenv("PULUMI_CREATE_EC2") == "true"
		if !createEC2 {
			ctx.Log.Info("PULUMI_CREATE_EC2 is not set to 'true' — skipping EC2 provisioning (no-op run).", nil)
			return nil
		}

		// ---------------------------------------------------------------
		// Config
		// ---------------------------------------------------------------
		projectName := cfg.Require("projectName")
		environment := cfg.Get("environment")
		if environment == "" {
			environment = "production"
		}
		sshPublicKey := cfg.RequireSecret("sshPublicKey")

		// ---------------------------------------------------------------
		// Look up the default VPC so we don't recreate networking
		// ---------------------------------------------------------------
		defaultVpc, err := ec2.LookupVpc(ctx, &ec2.LookupVpcArgs{
			Default: pulumi.BoolRef(true),
		}, nil)
		if err != nil {
			return err
		}

		defaultSubnets, err := ec2.GetSubnets(ctx, &ec2.GetSubnetsArgs{
			Filters: []ec2.GetSubnetsFilter{
				{
					Name:   "vpc-id",
					Values: []string{defaultVpc.Id},
				},
			},
		}, nil)
		if err != nil {
			return err
		}

		// ---------------------------------------------------------------
		// Security Group — via enterprise-infra-module Pulumi component
		// Component: pulumi/modules/aws/security-group → NewSecurityGroup
		// Outputs:   SecurityGroupID, SecurityGroupARN
		// ---------------------------------------------------------------
		sg, err := pulumiSG.NewSecurityGroup(ctx, projectName+"-pulumi-sg", &pulumiSG.Args{
			Name:        pulumi.String(projectName + "-pulumi-ec2-sg"),
			Description: pulumi.String("Security group for " + projectName + " Pulumi EC2"),
			VpcID:       pulumi.String(defaultVpc.Id),
			Project:     pulumi.String(projectName),
			Environment: pulumi.String(environment),
			IngressRules: pulumiSG.IngressRuleArray{
				&pulumiSG.IngressRuleArgs{
					FromPort:    pulumi.Int(22),
					ToPort:      pulumi.Int(22),
					Protocol:    pulumi.String("tcp"),
					CidrBlocks:  pulumi.StringArray{pulumi.String("0.0.0.0/0")},
					Description: pulumi.String("SSH"),
				},
				&pulumiSG.IngressRuleArgs{
					FromPort:    pulumi.Int(80),
					ToPort:      pulumi.Int(80),
					Protocol:    pulumi.String("tcp"),
					CidrBlocks:  pulumi.StringArray{pulumi.String("0.0.0.0/0")},
					Description: pulumi.String("HTTP"),
				},
				&pulumiSG.IngressRuleArgs{
					FromPort:    pulumi.Int(443),
					ToPort:      pulumi.Int(443),
					Protocol:    pulumi.String("tcp"),
					CidrBlocks:  pulumi.StringArray{pulumi.String("0.0.0.0/0")},
					Description: pulumi.String("HTTPS"),
				},
			},
			Tags: pulumi.StringMap{
				"Project":     pulumi.String(projectName),
				"Environment": pulumi.String(environment),
				"ManagedBy":   pulumi.String("pulumi"),
			},
		})
		if err != nil {
			return err
		}

		// ---------------------------------------------------------------
		// EC2 Instance — via enterprise-infra-module Pulumi component
		// Component: pulumi/modules/aws/ec2 → NewInstance
		// Outputs:   InstanceID, PublicIP, PrivateIP, SecurityGroupID
		// ---------------------------------------------------------------
		instance, err := pulumiEC2.NewInstance(ctx, projectName+"-pulumi-ec2", &pulumiEC2.Args{
			Name:             pulumi.String(projectName + "-pulumi-ec2"),
			Project:          pulumi.String(projectName),
			Environment:      pulumi.String(environment),
			SubnetID:         pulumi.String(defaultSubnets.Ids[0]),
			SecurityGroupIDs: pulumi.StringArray{sg.SecurityGroupID},
			SSHPublicKey:     sshPublicKey,
			AssociatePublicIP: pulumi.Bool(true),
			// AL2023 latest — AMI resolved by the module via data source
			// RootVolumeSize: module default (30GB minimum for AL2023)
		})
		if err != nil {
			return err
		}

		// ---------------------------------------------------------------
		// Stack outputs — readable via: pulumi stack output <name>
		// ---------------------------------------------------------------
		ctx.Export("pulumi_ec2_instance_id", instance.InstanceID)
		ctx.Export("pulumi_ec2_public_ip",   instance.PublicIP)
		ctx.Export("pulumi_ec2_private_ip",  instance.PrivateIP)
		ctx.Export("pulumi_sg_id",           sg.SecurityGroupID)

		return nil
	})
}
