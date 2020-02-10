# Download and install the module
Install-Module Autotask

# Connect to the Autotask Web Services API and load the module
# The first time you connect a disk cache will be created
$Credential = Get-Credential
$ApiKey = "FXUHZLUPSSL6SGBXXWMCNYMUDUA"
Import-Module Autotask -ArgumentList $Credential, $ApiKey


$contractlist = Get-AtwsContract -ContractCategory 'Managed ICT monatlich' -ServiceLevelAgreementID '01.01 Managed ICT Basic' -Status 'Active' | Where {($_.ExclusionContractID -eq $null) -and ($_.ContractName -notlike 'Leistungserfassung ausserhalb Managed ICT')}
$contractlist.AccountID


$dateNewEndDate = [datetime]::ParseExact('31.12.2021','dd.MM.yyyy',$null)
$dateNewEndDate

foreach($newcontract in $contractlist)
{
New-AtwsContract -AccountID $newcontract.AccountID -ContractName 'Leistungserfassung ausserhalb Managed ICT' -BillingPreference Manually -ContractCategory 'diverto Leistungserfassung' -ContractType Individual -Description 'Leistungserfassung ausserhalb Managed ICT' -StartDate '01.01.2019' -EndDate $dateNewEndDate -ServiceLevelAgreementID '01.01 Managed ICT Basic' -BusinessDivisionSubdivisionID 5 -ContractExclusionSetID 5 -Status Active -TimeReportingRequiresStartAndStopTimes False -EstimatedRevenue 0 -EstimatedHours 0 -EstimatedCost 0
$result = get-AtwsContract -ContractName 'Leistungserfassung ausserhalb Managed ICT' -AccountID $newcontract.AccountID
$result.id
new-atwscontractRate -ContractID $result.ID -RoleID 29683460 -ContractHourlyRate 160 -InternalCurrencyContractHourlyRate 160
new-atwscontractRate -ContractID $result.ID -RoleID 29683459 -ContractHourlyRate 160 -InternalCurrencyContractHourlyRate 160
new-atwscontractRate -ContractID $result.ID -RoleID 29683458 -ContractHourlyRate 175 -InternalCurrencyContractHourlyRate 175
}


#get-atwscontract -ContractName 'Leistungserfassung' -Status Active | set-atwscontract -EndDate $dateNewEndDate

#$copycontract = Get-AtwsContract -Id 29697415 | 
#get-atwsContractRate -ContractID 29697415
#Get-AtwsAccount -id 29683657