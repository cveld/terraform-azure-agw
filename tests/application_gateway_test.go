package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestApplyNoError(t *testing.T) {
	t.Parallel()

	tests := []string{
		"../examples/existing-vnet",
	}

	for _, test := range tests {
		t.Run(test, func(t *testing.T) {
			terraformOptions := &terraform.Options{
				TerraformDir: test,
				NoColor:      true,
				// Vars: map[string]interface{}{
				// 	"digicert_password": os.Getenv("DIGICERT_PASSWORD"),
				// },
			}

			terraform.WithDefaultRetryableErrors(t, &terraform.Options{})

			defer terraform.Destroy(t, terraformOptions)
			terraform.InitAndApply(t, terraformOptions)
		})
	}
}
