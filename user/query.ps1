<#
  .SYNOPSIS
  Queries Active Directory for information on specified user

  .DESCRIPTION
  The user.query plugin can query query Active Directory for user and group information 
  on specified user

  .PARAMETER UserName
  Specifies the username to look up

  .PARAMETER Filter
  Specifies a filter to apply when retrieving AD groups for specified user,
  only applicable when specifying any of the parameters for listing group
  membership

  .PARAMETER SearchBase
  Specifies a AD SearchBase to use when searching for indirect group
  membership
  
  .PARAMETER ListIndirectGroups
  Instructs the plugin to list indirect group membership for specified user

  .PARAMETER ListMemberGroups
  Instructs the plugin to list direct group membership for specified user

  .INPUTS
  None. You cannot pipe objects to Update-Month.ps1.

  .OUTPUTS
  General User information or User AD Member Listing

  .EXAMPLE
  PS> ecli user.query -u myusername -f Dev

  .EXAMPLE
  PS> ecli user.query -u myusername -lig -b "OU=My Security Groups,OU=MyTeam,DC=my-company,DC=example,DC=com"

#>

[CmdletBinding()]
param (
  [Parameter(ParameterSetName='main', Mandatory=$True, ValueFromPipelineByPropertyName=$False,Position=0)]
  [Alias('u')]
  $UserName,
  [Parameter(ParameterSetName='main', Mandatory=$False, ValueFromPipelineByPropertyName=$False,Position=1)]
  [Alias('f')]
  $Filter,
  [Parameter(ParameterSetName='main', Mandatory=$False, ValueFromPipelineByPropertyName=$False,Position=2)]
  [Alias('b')]
  $SearchBase,
  [Alias('gg')]
  [switch] $ListIndirectGroups,
  [Alias('g')]
  [switch] $ListMemberGroups,
  [Parameter(ParameterSetName='help')]
  [Alias('--help')]
  [switch] $Help

)

$__docstring__ = "Query User information from ActiveDirectory"

if($Help) {
  Get-Help $MYINVOCATION.InvocationName -full
  exit
}

if (-not $SearchBase -and $ListRelatedGroups) { 
  "You must specify the searchbase when attempting to list related groups"; exit 1
}

if ($(Get-Module -ListAvailable -Name ActiveDirectory)){
  Import-Module ActiveDirectory
} else {

  Write-Host "The ActiveDirectory Powershell Module is not installed!"
  Write-Host "Install by running: powershell 'Install-Module -Name ActiveDirectory'"
  throw "ModuleNotFound"
}

function ListUserMemberGroups {
  
  param(
      [Parameter(Mandatory=$true)]$User,
      [switch] $AsObject
      ) 

  "User $User is part of the following AD Groups:"
  if ($Filter) {
    $Groups = $(Get-ADPrincipalGroupMembership $User | `
    Where-Object { $_.name -match $Filter } | %{$_.name})
  } else {
    $Groups = $(Get-ADPrincipalGroupMembership $User | %{$_.name})
  }
  if ($AsObject) {
    return $Groups
  } else {
    ForEach ($Group in $($Groups | Sort-Object) ) {
      "- $Group"
    }
  }

}

function ListIndirectGroups {
  
  param(
      [Parameter(Mandatory=$true)]$User,
      [Parameter(Mandatory=$true)]$SearchBase
      ) 

  "The following is the list of AD Groups for which user '$User' is an indirect member:"
  $Groups = ListUserMemberGroups -User $User -AsObject
  $RelatedGroups = Get-ADGroup -SearchBase $SearchBase -Filter {name -like "*"} | `
  Where-Object { $_.Name -in $Groups }
  ForEach ($Group in $($RelatedGroups | Sort-Object) ) {
    "- $($Group.Name)"
  }
}

switch ($True) {
  ($ListMemberGroups)  { ListUserMemberGroups -User $Username  }
  ($ListIndirectGroups) { ListIndirectGroups -User $Username -SearchBase $SearchBase }
  default { Get-ADUser $UserName }
}