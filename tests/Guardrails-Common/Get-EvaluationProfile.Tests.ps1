BeforeAll {
    Import-Module "$PSScriptRoot/../../src/Guardrails-Common/GR-Common.psm1" -Force

    if (-not (Get-Command Get-AzTag -ErrorAction SilentlyContinue)) {
        function Get-AzTag { }
    }
}

Describe "Get-EvaluationProfile" {
    It "does not evaluate a subscription tagged with a profile that is not applicable to the module" {
        Mock Get-AzTag {
            [PSCustomObject]@{
                Properties = [PSCustomObject]@{
                    TagsProperty = @{
                        profile = "1"
                    }
                }
            }
        } -ModuleName GR-Common

        $result = Get-EvaluationProfile -CloudUsageProfiles "[1, 2, 3, 6]" -ModuleProfiles "3,6" -SubscriptionId "00000000-0000-0000-0000-000000000000"

        $result.Profile | Should -Be 1
        $result.ShouldEvaluate | Should -BeFalse
    }

    It "evaluates a subscription tagged with a profile that is enabled and applicable to the module" {
        Mock Get-AzTag {
            [PSCustomObject]@{
                Properties = [PSCustomObject]@{
                    TagsProperty = @{
                        profile = "6"
                    }
                }
            }
        } -ModuleName GR-Common

        $result = Get-EvaluationProfile -CloudUsageProfiles "[1, 2, 3, 6]" -ModuleProfiles "3,6" -SubscriptionId "00000000-0000-0000-0000-000000000000"

        $result.Profile | Should -Be 6
        $result.ShouldEvaluate | Should -BeTrue
    }
}
