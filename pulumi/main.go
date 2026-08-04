// Pulumi EC2 vending machine — infra-vending-machine
//
// Toggle: set PULUMI_CREATE_EC2=true in the pipeline env to provision the EC2.
// Default is false — a bare run is always a no-op (preview only).
//
// Resources created directly with pulumi-aws SDK v6 (no external wrapper module):
//   - aws.ec2.SecurityGroup  (SSH 22, HTTP 80, HTTPS 443)
//   - aws.ec2.KeyPair        (project SSH key from stack secret)
//   - aws.ec2.Instance       (AL2023, t3.micro, default VPC, 30 GB root)
//
// State backend: Pulumi Cloud (PULUMI_ACCESS_TOKEN secret required)
// Stack:         prod  (Pulumi.prod.yaml sets aws:region = us-east-1)

package main

import (
	"os"

	"github.com/pulumi/pulumi-aws/sdk/v6/go/aws/ec2"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi/config"
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
		// Look up the default VPC and first subnet
		// ---------------------------------------------------------------
		defaultVpc, err := ec2.LookupVpc(ctx, &ec2.LookupVpcArgs{
			Default: pulumi.BoolRef(true),
		}, nil)
		if err != nil {
			return err
		}

		defaultSubnets, err := ec2.GetSubnets(ctx, &ec2.GetSubnetsArgs{
			Filters: []ec2.GetSubnetsFilter{
				{Name: "vpc-id", Values: []string{defaultVpc.Id}},
			},
		}, nil)
		if err != nil {
			return err
		}

		// ---------------------------------------------------------------
		// Security Group
		// ---------------------------------------------------------------
		sg, err := ec2.NewSecurityGroup(ctx, projectName+"-pulumi-sg", &ec2.SecurityGroupArgs{
			Name:        pulumi.String(projectName + "-pulumi-ec2-sg"),
			Description: pulumi.String("Security group for " + projectName + " Pulumi EC2"),
			VpcId:       pulumi.String(defaultVpc.Id),
			Ingress: ec2.SecurityGroupIngressArray{
				&ec2.SecurityGroupIngressArgs{
					FromPort:   pulumi.Int(22),
					ToPort:     pulumi.Int(22),
					Protocol:   pulumi.String("tcp"),
					CidrBlocks: pulumi.StringArray{pulumi.String("0.0.0.0/0")},
					Description: pulumi.String("SSH"),
				},
				&ec2.SecurityGroupIngressArgs{
					FromPort:   pulumi.Int(80),
					ToPort:     pulumi.Int(80),
					Protocol:   pulumi.String("tcp"),
					CidrBlocks: pulumi.StringArray{pulumi.String("0.0.0.0/0")},
					Description: pulumi.String("HTTP"),
				},
				&ec2.SecurityGroupIngressArgs{
					FromPort:   pulumi.Int(443),
					ToPort:     pulumi.Int(443),
					Protocol:   pulumi.String("tcp"),
					CidrBlocks: pulumi.StringArray{pulumi.String("0.0.0.0/0")},
					Description: pulumi.String("HTTPS"),
				},
			},
			Egress: ec2.SecurityGroupEgressArray{
				&ec2.SecurityGroupEgressArgs{
					FromPort:   pulumi.Int(0),
					ToPort:     pulumi.Int(0),
					Protocol:   pulumi.String("-1"),
					CidrBlocks: pulumi.StringArray{pulumi.String("0.0.0.0/0")},
				},
			},
			Tags: pulumi.StringMap{
				"Name":        pulumi.String(projectName + "-pulumi-ec2-sg"),
				"Project":     pulumi.String(projectName),
				"Environment": pulumi.String(environment),
				"ManagedBy":   pulumi.String("pulumi"),
			},
		})
		if err != nil {
			return err
		}

		// ---------------------------------------------------------------
		// Key Pair (from stack secret)
		// ---------------------------------------------------------------
		keyPair, err := ec2.NewKeyPair(ctx, projectName+"-pulumi-key", &ec2.KeyPairArgs{
			KeyName:   pulumi.String(projectName + "-pulumi-key"),
			PublicKey: sshPublicKey,
			Tags: pulumi.StringMap{
				"Project":   pulumi.String(projectName),
				"ManagedBy": pulumi.String("pulumi"),
			},
		})
		if err != nil {
			return err
		}

		// ---------------------------------------------------------------
		// AMI — latest AL2023 x86_64
		// ---------------------------------------------------------------
		ami, err := ec2.LookupAmi(ctx, &ec2.LookupAmiArgs{
			MostRecent: pulumi.BoolRef(true),
			Owners:     []string{"amazon"},
			Filters: []ec2.GetAmiFilter{
				{Name: "name", Values: []string{"al2023-ami-*-x86_64"}},
				{Name: "architecture", Values: []string{"x86_64"}},
				{Name: "virtualization-type", Values: []string{"hvm"}},
			},
		}, nil)
		if err != nil {
			return err
		}

		// ---------------------------------------------------------------
		// EC2 Instance
		// ---------------------------------------------------------------
		instance, err := ec2.NewInstance(ctx, projectName+"-pulumi-ec2", &ec2.InstanceArgs{
			Ami:                      pulumi.String(ami.Id),
			InstanceType:             pulumi.String("t3.micro"),
			SubnetId:                 pulumi.String(defaultSubnets.Ids[0]),
			VpcSecurityGroupIds:      pulumi.StringArray{sg.ID()},
			KeyName:                  keyPair.KeyName,
			AssociatePublicIpAddress: pulumi.Bool(true),
			RootBlockDevice: &ec2.InstanceRootBlockDeviceArgs{
				VolumeSize: pulumi.Int(30),
				VolumeType: pulumi.String("gp3"),
			},
			Tags: pulumi.StringMap{
				"Name":        pulumi.String(projectName + "-pulumi-ec2"),
				"Project":     pulumi.String(projectName),
				"Environment": pulumi.String(environment),
				"ManagedBy":   pulumi.String("pulumi"),
			},
		})
		if err != nil {
			return err
		}

		// ---------------------------------------------------------------
		// Stack outputs — readable via: pulumi stack output <name>
		// ---------------------------------------------------------------
		ctx.Export("pulumi_ec2_instance_id", instance.ID())
		ctx.Export("pulumi_ec2_public_ip", instance.PublicIp)
		ctx.Export("pulumi_ec2_private_ip", instance.PrivateIp)
		ctx.Export("pulumi_sg_id", sg.ID())

		return nil
	})
}
