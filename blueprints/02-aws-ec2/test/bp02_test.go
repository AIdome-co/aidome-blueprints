// Package test contains integration tests for Blueprint 02 (AWS EC2 – Single Node).
//
// # Overview
//
// Each sub-test provisions a real AWS environment (VPC, NAT GW, EC2 instance)
// using Terraform, waits for cloud-init to complete, and asserts that the
// expected services (Docker, SSM Agent, iptables DOCKER-USER chain, and the
// aidome-ops operator user) are correctly configured.
//
// The tests are designed to run in parallel, one sub-test per OS type, in a
// nightly scheduled workflow. They are NOT suitable as a per-PR gate because
// they require real AWS infrastructure and take 25–40 minutes to complete.
//
// # Prerequisites
//
//   - AWS credentials with the following permissions in the test account:
//     ec2:*, iam:*, sts:GetCallerIdentity, ssm:SendCommand,
//     ssm:GetCommandInvocation, ssm:DescribeInstanceInformation
//   - Environment variable TEST_AWS_REGION (optional; defaults to us-east-1)
//
// # Running
//
//	cd blueprints/02-aws-ec2/test
//	go test -v -run TestBlueprint02 -timeout 60m ./...
//
// To test a single OS type:
//
//	go test -v -run "TestBlueprint02/ubuntu-2404" -timeout 60m ./...
package test

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ssm"
	ttaws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const (
	// defaultRegion is the fallback AWS region. Override with TEST_AWS_REGION.
	defaultRegion = "us-east-1"

	// ssmPollInterval is how often we re-query SSM while waiting.
	ssmPollInterval = 30 * time.Second

	// ssmRegistrationTimeout is the maximum time we wait for an instance to
	// appear in SSM (includes cloud-init first run + reboot).
	ssmRegistrationTimeout = 20 * time.Minute

	// cloudInitTimeout is the maximum time we wait for cloud-init status=done
	// after SSM is registered (instance has rebooted and come back online).
	cloudInitTimeout = 30 * time.Minute

	// ssmCmdTimeout is the per-command SSM execution timeout (seconds).
	ssmCmdTimeout = 120
)

// osTestCase describes a single OS variant to validate.
type osTestCase struct {
	// name must match an os_type value accepted by the blueprint variables.
	name string
	// amiOwner is the canonical AWS account ID that publishes official AMIs.
	amiOwner string
	// amiFilter is the name glob pattern for aws.GetMostRecentAmiIdE.
	amiFilter string
	// sudoGroup is the group that grants passwordless sudo on this OS family.
	// Debian family: "sudo"; RHEL family: "wheel".
	sudoGroup string
}

// osCases is the representative subset tested on every nightly run.
// Covers both OS families and the two most common RHEL-compatible distros.
var osCases = []osTestCase{
	{
		name:      "ubuntu-2404",
		amiOwner:  "099720109477", // Canonical Ltd.
		amiFilter: "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*",
		sudoGroup: "sudo",
	},
	{
		name:      "debian-12",
		amiOwner:  "136693071363", // Debian Project
		amiFilter: "debian-12-amd64-*",
		sudoGroup: "sudo",
	},
	{
		name:      "rhel-9",
		amiOwner:  "309956199498", // Red Hat (on-demand, subscription included in EC2 price)
		amiFilter: "RHEL-9.*_HVM-*-x86_64-*",
		sudoGroup: "wheel",
	},
	{
		name:      "almalinux-9",
		amiOwner:  "764336703387", // AlmaLinux OS Foundation
		amiFilter: "AlmaLinux OS 9*x86_64*",
		sudoGroup: "wheel",
	},
}

// TestBlueprint02 runs all OS sub-tests in parallel.
// Use -run "TestBlueprint02/ubuntu-2404" to target a single OS.
func TestBlueprint02(t *testing.T) {
	for _, tc := range osCases {
		tc := tc // capture range variable for goroutine
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			testBlueprint02OS(t, tc)
		})
	}
}

// testBlueprint02OS provisions a full test environment for one OS type,
// runs assertions, and destroys all resources on exit.
func testBlueprint02OS(t *testing.T, tc osTestCase) {
	awsRegion := envOrDefault("TEST_AWS_REGION", defaultRegion)

	// Unique prefix prevents resource-name collisions across parallel runs.
	namePrefix := fmt.Sprintf("tt-bp02-%s-%s",
		strings.ReplaceAll(tc.name, "-", ""),
		random.UniqueId(),
	)

	t.Logf("[%s] Region: %s  Prefix: %s", tc.name, awsRegion, namePrefix)

	// Resolve the most-recent AMI for this OS type in the target region.
	amiID, err := ttaws.GetMostRecentAmiIdE(t, awsRegion, tc.amiOwner, map[string][]string{
		"name":  {tc.amiFilter},
		"state": {"available"},
	})
	require.NoError(t, err, "[%s] AMI lookup failed", tc.name)
	t.Logf("[%s] AMI: %s", tc.name, amiID)

	tfOpts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "fixtures",
		Vars: map[string]interface{}{
			"name_prefix":   namePrefix,
			"ami_id":        amiID,
			"os_type":       tc.name,
			"aws_region":    awsRegion,
			"instance_type": "t3.medium", // enough RAM for Docker
		},
		NoColor: true,
	})

	// Always destroy — even on test failure or panic.
	defer terraform.Destroy(t, tfOpts)

	terraform.InitAndApply(t, tfOpts)

	instanceID := terraform.Output(t, tfOpts, "instance_id")
	t.Logf("[%s] Instance: %s", tc.name, instanceID)

	// Wait for the SSM agent to register (survives the cloud-init reboot).
	t.Logf("[%s] Waiting for SSM registration (up to %s)...", tc.name, ssmRegistrationTimeout)
	waitForSSMOnline(t, awsRegion, instanceID, ssmRegistrationTimeout)

	// cloud-init reboots the instance on first completion; wait for done status.
	t.Logf("[%s] Waiting for cloud-init done (up to %s)...", tc.name, cloudInitTimeout)
	waitForCloudInit(t, awsRegion, instanceID, cloudInitTimeout)

	// Run all assertions.
	t.Logf("[%s] Running assertions...", tc.name)
	assertBlueprint(t, awsRegion, instanceID, tc)
}

// assertBlueprint checks all post-bootstrap invariants on the instance.
func assertBlueprint(t *testing.T, awsRegion, instanceID string, tc osTestCase) {
	t.Helper()

	// cloud-init must finish without error.
	ciStatus := runSSMCmd(t, awsRegion, instanceID, "cloud-init status 2>/dev/null || echo unknown")
	assert.Contains(t, ciStatus, "done",
		"[%s] cloud-init should report 'done'; got: %s", tc.name, ciStatus)

	// Docker must be active and the daemon socket must be up.
	dockerStatus := runSSMCmd(t, awsRegion, instanceID, "systemctl is-active docker 2>/dev/null || echo inactive")
	assert.Equal(t, "active", strings.TrimSpace(dockerStatus),
		"[%s] Docker should be active", tc.name)

	dockerVersion := runSSMCmd(t, awsRegion, instanceID, "docker --version 2>/dev/null || echo missing")
	assert.Contains(t, dockerVersion, "Docker version",
		"[%s] docker --version should succeed", tc.name)

	// SSM Agent must be running (may be the snap unit on Ubuntu).
	ssmStatus := runSSMCmd(t, awsRegion, instanceID,
		"systemctl is-active amazon-ssm-agent 2>/dev/null || "+
			"systemctl is-active snap.amazon-ssm-agent.amazon-ssm-agent 2>/dev/null || "+
			"echo inactive",
	)
	assert.Equal(t, "active", strings.TrimSpace(ssmStatus),
		"[%s] SSM Agent should be active", tc.name)

	// DOCKER-USER chain must contain a DROP rule (prevents container bypass).
	dockerUser := runSSMCmd(t, awsRegion, instanceID,
		"iptables -L DOCKER-USER -n 2>/dev/null || echo 'chain-missing'")
	assert.Contains(t, dockerUser, "DROP",
		"[%s] DOCKER-USER chain should contain a DROP rule", tc.name)

	// aidome-ops user must exist and belong to the correct groups.
	idOutput := runSSMCmd(t, awsRegion, instanceID, "id aidome-ops 2>/dev/null || echo 'user-missing'")
	assert.Contains(t, idOutput, "docker",
		"[%s] aidome-ops should be in docker group", tc.name)
	assert.Contains(t, idOutput, tc.sudoGroup,
		"[%s] aidome-ops should be in %s group", tc.name, tc.sudoGroup)
}

// -------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------

// runSSMCmd sends a shell command to an EC2 instance via SSM Run Command
// (AWS-RunShellScript) and returns the trimmed stdout. The test fails if
// the command cannot be sent or does not complete within 3 minutes.
func runSSMCmd(t *testing.T, awsRegion, instanceID, command string) string {
	t.Helper()

	sess := session.Must(session.NewSession(&aws.Config{Region: aws.String(awsRegion)}))
	svc := ssm.New(sess)

	sendOut, err := svc.SendCommand(&ssm.SendCommandInput{
		DocumentName:   aws.String("AWS-RunShellScript"),
		InstanceIds:    []*string{aws.String(instanceID)},
		TimeoutSeconds: aws.Int64(ssmCmdTimeout),
		Parameters:     map[string][]*string{"commands": {aws.String(command)}},
	})
	require.NoError(t, err, "SSM SendCommand failed (cmd: %q)", command)

	cmdID := aws.StringValue(sendOut.Command.CommandId)

	// Poll for completion (max 3 minutes).
	deadline := time.Now().Add(3 * time.Minute)
	for time.Now().Before(deadline) {
		time.Sleep(5 * time.Second)

		inv, err := svc.GetCommandInvocation(&ssm.GetCommandInvocationInput{
			CommandId:  aws.String(cmdID),
			InstanceId: aws.String(instanceID),
		})
		if err != nil {
			continue
		}

		switch aws.StringValue(inv.StatusDetails) {
		case "Pending", "InProgress", "Delayed":
			continue
		default:
			return strings.TrimSpace(aws.StringValue(inv.StandardOutputContent))
		}
	}

	t.Fatalf("SSM command timed out (cmd: %q, instance: %s)", command, instanceID)
	return ""
}

// waitForSSMOnline polls DescribeInstanceInformation until the instance shows
// PingStatus=Online, indicating the SSM agent has (re-)registered after the
// cloud-init reboot.
func waitForSSMOnline(t *testing.T, awsRegion, instanceID string, maxWait time.Duration) {
	t.Helper()

	sess := session.Must(session.NewSession(&aws.Config{Region: aws.String(awsRegion)}))
	svc := ssm.New(sess)

	deadline := time.Now().Add(maxWait)
	for time.Now().Before(deadline) {
		out, err := svc.DescribeInstanceInformation(&ssm.DescribeInstanceInformationInput{
			Filters: []*ssm.InstanceInformationStringFilter{
				{Key: aws.String("InstanceIds"), Values: []*string{aws.String(instanceID)}},
			},
		})
		if err == nil && len(out.InstanceInformationList) > 0 {
			if aws.StringValue(out.InstanceInformationList[0].PingStatus) == "Online" {
				t.Logf("Instance %s is SSM Online", instanceID)
				return
			}
		}
		time.Sleep(ssmPollInterval)
	}

	t.Fatalf("Instance %s did not reach SSM Online within %v", instanceID, maxWait)
}

// waitForCloudInit polls cloud-init status via SSM until it reports "done"
// or "error". A status of "error" is logged as a warning (not a test failure)
// so that the assertion step can capture the specific item that failed.
func waitForCloudInit(t *testing.T, awsRegion, instanceID string, maxWait time.Duration) {
	t.Helper()

	deadline := time.Now().Add(maxWait)
	for time.Now().Before(deadline) {
		status := runSSMCmd(t, awsRegion, instanceID,
			"cloud-init status 2>/dev/null || echo unknown")

		if strings.Contains(status, "done") {
			t.Logf("cloud-init status: done")
			return
		}
		if strings.Contains(status, "error") {
			t.Logf("Warning: cloud-init reported error status (%s); proceeding with assertions", status)
			return
		}

		t.Logf("cloud-init status: %s — waiting...", strings.TrimSpace(status))
		time.Sleep(60 * time.Second)
	}

	t.Logf("Warning: timed out waiting for cloud-init after %v; proceeding with assertions", maxWait)
}

// envOrDefault returns the value of the environment variable key, or fallback
// if the variable is not set or empty.
func envOrDefault(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
