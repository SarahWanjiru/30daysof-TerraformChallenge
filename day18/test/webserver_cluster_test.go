package test

import (
	"fmt"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestWebserverClusterIntegration(t *testing.T) {
	t.Parallel()

	// unique ID prevents name conflicts when tests run in parallel
	uniqueID := random.UniqueId()
	clusterName := fmt.Sprintf("test-cluster-%s", uniqueID)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/services/webserver-cluster",
		Vars: map[string]interface{}{
			"cluster_name":   clusterName,
			"instance_type":  "t3.micro",
			"min_size":       1,
			"max_size":       2,
			"environment":    "dev",
			"project_name":   "terratest",
			"team_name":      "sarahcodes",
			"db_secret_name": "day13/db/credentials",
		},
	})

	// defer guarantees destroy runs even if assertions fail
	// without this, a failed test leaves real AWS resources running and incurring cost
	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
	url := fmt.Sprintf("http://%s", albDnsName)

	// retry for up to 5 minutes — ALB takes time to register instances and pass health checks
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		url,
		nil,
		30,
		10*time.Second,
		func(status int, body string) bool {
			return status == 200 && len(body) > 0
		},
	)

	assert.NotEmpty(t, albDnsName, "ALB DNS name should not be empty")
}
