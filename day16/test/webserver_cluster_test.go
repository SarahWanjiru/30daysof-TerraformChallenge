package test

import (
	"fmt"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestWebserverCluster(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/services/webserver-cluster",
		Vars: map[string]interface{}{
			"cluster_name":  "test-cluster",
			"instance_type": "t3.micro",
			"min_size":      1,
			"max_size":      2,
			"environment":   "dev",
			"project_name":  "terratest",
			"team_name":     "sarahcodes",
		},
	})

	// defer runs terraform destroy after the test finishes — even if the test fails
	// without this, a failed test would leave real AWS resources running and incurring cost
	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
	url := fmt.Sprintf("http://%s", albDnsName)

	// retry for up to 5 minutes — instances take time to pass health checks
	http_helper.HttpGetWithRetry(t, url, nil, 200, "Hello", 30, 10*time.Second)
}
