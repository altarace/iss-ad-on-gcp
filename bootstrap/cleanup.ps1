#
#  Copyright 2018 Google Inc.
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#    http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

Function Set-RuntimeConfigVariable {
        Param(
		[Parameter(Mandatory=$True)][String] $ConfigPath,
		[Parameter(Mandatory=$True)][String] $Variable,
		[Parameter(Mandatory=$True)][String] $Text
        )

	$Auth = $(gcloud auth print-access-token)

	$Path = "$ConfigPath/variables"
	$Url = "https://runtimeconfig.googleapis.com/v1beta1/$Path"

	$Json = (@{
	name = "$Path/$Variable"
	text = $Text
	} | ConvertTo-Json)

	$Headers = @{
	Authorization = "Bearer " + $Auth
	}

	$Params = @{
	Method = "POST"
	Headers = $Headers
	ContentType = "application/json"
	Uri = $Url
	Body = $Json
	}

	Try {
		Return Invoke-RestMethod @Params
	}
	Catch {
	        $Reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        	$ErrResp = $Reader.ReadToEnd() | ConvertFrom-Json
        	$Reader.Close()
		Return $ErrResp
	}

}

Function Unwrap-SecureString() {
	Param(
		[System.Security.SecureString] $SecureString
	)
	Return (New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', $SecureString).Password
}

Function Get-GoogleMetadata() {
	Param (
	[Parameter(Mandatory=$True)][String] $Path
	)
	Try {
		Return Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/$Path
	}
	Catch {
		Return $Null
	}
}

Function Get-Setting {
	Param (
	[Parameter(Mandatory=$True)][String][ValidateNotNullOrEmpty()]
	$Path
	)

	$GcsPrefix = Get-GoogleMetadata -Path "instance/attributes/gcs-prefix"
	If ($GcsPrefix.EndsWith("/")) {
		$GcsPrefix = $GcsPrefix -Replace ".$"
	}
	$Value = gsutil -q cat "$GcsPrefix/settings/$Path"
	Return $Value

}


# turn off gcloud version checks
gcloud config set component_manager/disable_update_check true


Write-Host "Getting settings..."
$ResLoc = Get-GoogleMetadata "instance/attributes/resource-location"
$MacCat = Get-GoogleMetadata "instance/attributes/machine-catalog"
$DelGro = Get-GoogleMetadata "instance/attributes/delivery-group"
$HosCon = Get-GoogleMetadata "instance/attributes/hosting-connection"


# delete instance
$name = Get-GoogleMetadata "instance/name"
$zone = Get-GoogleMetadata "instance/zone"
gcloud compute instances delete "$name" --zone "$zone"

