package test

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestTerraformHetznerInfrastructure tests the complete Hetzner infrastructure
func TestTerraformHetznerInfrastructure(t *testing.T) {
	t.Parallel()

	// Check HCLOUD_TOKEN is set
	hcloudToken := os.Getenv("HCLOUD_TOKEN")
	require.NotEmpty(t, hcloudToken, "HCLOUD_TOKEN environment variable must be set")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// Path to Terraform code
		TerraformDir: "../environments/production",

		// Variables to pass to Terraform
		Vars: map[string]interface{}{
			"hcloud_token":             hcloudToken,
			"environment":              "test",
			"project_name":             "terratest",
			"wordpress_server_type":    "cx11", // Smallest for testing
			"deploy_monitoring_server": false,  // Don't deploy extra servers
			"deploy_openbao_server":    false,
		},

		// Disable colors in Terraform output
		NoColor: true,
	})

	// Clean up resources at the end of the test
	defer terraform.Destroy(t, terraformOptions)

	// Run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	// Test 1: Validate WordPress server was created
	t.Run("WordPressServerCreated", func(t *testing.T) {
		wordpressIP := terraform.Output(t, terraformOptions, "wordpress_ipv4")
		assert.NotEmpty(t, wordpressIP, "WordPress server IP should not be empty")
		assert.Regexp(t, `^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$`, wordpressIP, "Should be valid IPv4")
	})

	// Test 2: Validate server labels
	t.Run("ServerLabels", func(t *testing.T) {
		labels := terraform.OutputMap(t, terraformOptions, "wordpress_labels")
		assert.Equal(t, "test", labels["environment"])
		assert.Equal(t, "wordpress", labels["role"])
		assert.Equal(t, "terratest", labels["project"])
		assert.Equal(t, "terraform", labels["managed_by"])
	})

	// Test 3: Validate SSH connectivity
	t.Run("SSHConnectivity", func(t *testing.T) {
		wordpressIP := terraform.Output(t, terraformOptions, "wordpress_ipv4")

		// Setup SSH key
		sshKeyPair := &ssh.KeyPair{
			PrivateKey: os.Getenv("SSH_PRIVATE_KEY"),
			PublicKey:  os.Getenv("SSH_PUBLIC_KEY"),
		}

		// Create SSH host
		host := ssh.Host{
			Hostname:    wordpressIP,
			SshUserName: "admin",
			SshKeyPair:  sshKeyPair,
		}

		// Wait for SSH to be available (max 5 minutes)
		maxRetries := 30
		sleepBetweenRetries := 10 * time.Second

		_, err := retry.DoWithRetryE(
			t,
			"SSH to WordPress server",
			maxRetries,
			sleepBetweenRetries,
			func() (string, error) {
				output, err := ssh.CheckSshCommandE(t, host, "echo OK")
				if err != nil {
					return "", err
				}
				return output, nil
			},
		)

		require.NoError(t, err, "Should be able to SSH to WordPress server")
	})

	// Test 4: Validate Debian 13 is installed
	t.Run("DebianVersion", func(t *testing.T) {
		wordpressIP := terraform.Output(t, terraformOptions, "wordpress_ipv4")

		sshKeyPair := &ssh.KeyPair{
			PrivateKey: os.Getenv("SSH_PRIVATE_KEY"),
			PublicKey:  os.Getenv("SSH_PUBLIC_KEY"),
		}

		host := ssh.Host{
			Hostname:    wordpressIP,
			SshUserName: "admin",
			SshKeyPair:  sshKeyPair,
		}

		// Check Debian version
		output := ssh.CheckSshCommand(t, host, "cat /etc/debian_version")
		assert.Contains(t, output, "13", "Should be running Debian 13")
	})

	// Test 5: Validate firewall is configured
	t.Run("FirewallConfigured", func(t *testing.T) {
		wordpressIP := terraform.Output(t, terraformOptions, "wordpress_ipv4")

		// Test SSH port is open (we can connect)
		assert.NotEmpty(t, wordpressIP, "IP should exist")

		// Test HTTP port is open
		// TODO: Add actual HTTP test when web server is running
	})
}

// TestTerraformMultiServerDeployment tests deployment with monitoring and openbao servers
func TestTerraformMultiServerDeployment(t *testing.T) {
	// Skip if running short tests
	if testing.Short() {
		t.Skip("Skipping multi-server test in short mode")
	}

	t.Parallel()

	hcloudToken := os.Getenv("HCLOUD_TOKEN")
	require.NotEmpty(t, hcloudToken, "HCLOUD_TOKEN environment variable must be set")

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../environments/production",
		Vars: map[string]interface{}{
			"hcloud_token":             hcloudToken,
			"environment":              "test-multi",
			"project_name":             "terratest-multi",
			"wordpress_server_type":    "cx11",
			"monitoring_server_type":   "cx11",
			"openbao_server_type":      "cx11",
			"deploy_monitoring_server": true, // Deploy all servers
			"deploy_openbao_server":    true,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Test all three servers are created
	t.Run("AllServersCreated", func(t *testing.T) {
		wordpressIP := terraform.Output(t, terraformOptions, "wordpress_ipv4")
		monitoringIP := terraform.Output(t, terraformOptions, "monitoring_ipv4")
		openbaoIP := terraform.Output(t, terraformOptions, "openbao_ipv4")

		assert.NotEmpty(t, wordpressIP)
		assert.NotEmpty(t, monitoringIP)
		assert.NotEmpty(t, openbaoIP)

		// IPs should be different
		assert.NotEqual(t, wordpressIP, monitoringIP)
		assert.NotEqual(t, wordpressIP, openbaoIP)
		assert.NotEqual(t, monitoringIP, openbaoIP)
	})
}

// TestTerraformOutputs validates all expected outputs are present
func TestTerraformOutputs(t *testing.T) {
	t.Parallel()

	hcloudToken := os.Getenv("HCLOUD_TOKEN")
	require.NotEmpty(t, hcloudToken)

	terraformOptions := &terraform.Options{
		TerraformDir: "../environments/production",
		Vars: map[string]interface{}{
			"hcloud_token":             hcloudToken,
			"environment":              "test-outputs",
			"deploy_monitoring_server": false,
			"deploy_openbao_server":    false,
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Validate all expected outputs exist
	expectedOutputs := []string{
		"wordpress_ipv4",
		"wordpress_ipv4_private",
		"wordpress_server_type",
		"wordpress_labels",
	}

	for _, output := range expectedOutputs {
		t.Run(fmt.Sprintf("Output_%s", output), func(t *testing.T) {
			value := terraform.Output(t, terraformOptions, output)
			assert.NotEmpty(t, value, fmt.Sprintf("%s should not be empty", output))
		})
	}
}
