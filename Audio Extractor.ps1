function Create-xLiveDefaultChannelMap{
    param(
        [switch]$AsString
    )
    #Default channel map YAML
	$ChannelMapYaml = @'
tracks:
- track: Mono1
  channels:
  - 1

- track: Mono2
  channels:
  - 2

- track: Mono3
  channels:
  - 3

- track: Mono4
  channels:
  - 4

- track: Mono5
  channels:
  - 5

- track: Mono6
  channels:
  - 6

- track: Mono7
  channels:
  - 7

- track: Mono8
  channels:
  - 8

- track: Mono9
  channels:
  - 9

- track: Mono10
  channels:
  - 10

- track: Mono11
  channels:
  - 11

- track: Mono12
  channels:
  - 12

- track: Mono13
  channels:
  - 13

- track: Mono14
  channels:
  - 14

- track: Mono15
  channels:
  - 15

- track: Mono16
  channels:
  - 16

- track: Mono17
  channels:
  - 17

- track: Mono18
  channels:
  - 18

- track: Mono19
  channels:
  - 19

- track: Mono20
  channels:
  - 20

- track: Mono21
  channels:
  - 21

- track: Mono22
  channels:
  - 22

- track: Mono23
  channels:
  - 23

- track: Mono24
  channels:
  - 24

- track: Mono25
  channels:
  - 25

- track: Mono26
  channels:
  - 26

- track: Mono27
  channels:
  - 27

- track: Mono28
  channels:
  - 28

- track: Mono29
  channels:
  - 29

- track: Mono30
  channels:
  - 30

- track: Mono31
  channels:
  - 31

- track: Mono32
  channels:
  - 32
  enable: true
'@
	if($AsString){
	    Write-Output $ChannelMapYaml
    }
    else{
        $temp = $ChannelMapYaml | ConvertFrom-Yaml
        Write-Output $temp
    }
}

function Out-xLiveAudioTracks{
	[CmdletBinding()]
	param(
	    [Parameter(Position=0,Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({
            $inputDir = [System.IO.Path]::GetDirectoryName($_)
            if( -Not ($inputDir | Test-Path) ){
                throw "Path for parameter 'InputFilePath' '$inputDir' not found"
            }
            if($_ -notmatch "(\.wav)"){
                throw "Path for parameter 'InputFilePath' must be of type 'WAV'. This can be a wildcard e.g. '*.wav'"
            }
            $files = Get-ChildItem -Path $_ | Where-Object -FilterScript {$_.Name -match '^[0-9]{8}\.wav'}
            if(-Not ($files -and $files.count -gt 0) ){
                throw "Path for parameter 'InputFilePath' does not include any files that match the expected XLive name format e.g. '00000001.wav'"
            }
            return $true
        })]
		[string]$InputFilePath,

		[Parameter(Position=0,Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({
            if( -Not ($_ | Test-Path) ){
                #throw "'$_' not found."
                [System.IO.Directory]::CreateDirectory($_)
            }
            if(-Not ($_ | Test-Path -PathType Container) ){
                throw "The 'OutputPath' parameter must point to a folder. File paths are not allowed."
            }
            return $true
        })]
		[System.IO.FileInfo]$OutputPath = "$Env:Temp\xLiveImport",

        [Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({
            if(!$_){
                throw "'ChannelMap' cannot be empty. Provide a Channel map yaml file path or object."
            }
            return $true
        })]
		[object]$ChannelMap = $(Create-xLiveDefaultChannelMap),

        [Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({
            if( -Not ($_ | Test-Path) ){
                [System.IO.Directory]::CreateDirectory($_)
            }
            if(-Not ($_ | Test-Path -PathType Container) ){
                throw "The 'WorkingDirectory' parameter must point to a folder. File paths are not allowed."
            }
            return $true
        })]
		[string]$WorkingDirectory = "$Env:Temp\xlivetemp",

		#[Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
		#[string]$InputFileFilter = '*.wav',

		[Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({
            if( -Not ($_ | Test-Path) ){
                throw "'$_' not found."
            }
            if(-Not ($_ | Test-Path -PathType Leaf) ){
                throw "The 'ffmpegPath' parameter must point to the ffmpeg.exe file. Folder paths are not allowed."
            }
            return $true
        })]
		[System.IO.FileInfo]$FFMpegPath = $(Join-Path $PSScriptRoot 'ffmpeg-20200619-2f59946-win64-static\bin\ffmpeg.exe'),

		[Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [switch]$Force,

        [Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
		[switch]$NoCleanup,

        [Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
		[int]$MaxFFMpegProcesses = 8,

        [Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
		[switch]$TestRun
	)
	begin{


        if( -Not ($WorkingDirectory | Test-Path) ){
            [System.IO.Directory]::CreateDirectory($WorkingDirectory)
        }

        #Get Channel Map
        if($ChannelMap -is [string]){
            #Could be YAML or file path
            try{
                #Is it a file path?
                [System.IO.FileInfo]$tPath = $ChannelMap
                if( -Not ($tPath | Test-Path) ){
                    throw "'$tPath' not found."
                }
                $rawYAML = Get-Content -LiteralPath $tPath -Raw
            }
            catch{
                #Must be YAML?
                $rawYAML = $ChannelMap
            }

            if($rawYAML){
                try{
                    Write-Verbose "Attempting to convert YAML string to object."
                    $ChannelMapObject = $rawYAML | ConvertFrom-Yaml
                }
                catch{

                }
            }
            else{
                throw "Unable to read channel map data from string input."
            }
        }
        elseif($ChannelMap -is [hashtable]){
            $ChannelMapObject = $ChannelMap
        }
        else{
            throw "Parameter 'ChannelMap' is not of the expected type."
        }

        if(!$ChannelMapObject -or !$ChannelMapObject.tracks){
            Write-Error "Channel map not in correct format." -ErrorAction Stop
        }

	}
	process{
		$Files = Get-ChildItem -Path $InputFilePath

        $FileNameList = @{}
        $procList = @()
		foreach($FileName in $Files | Sort-Object | Select-Object -ExpandProperty FullName){
			$OutFilenamePrefix = [System.IO.Path]::GetFileNameWithoutExtension($FileName).Replace(".", "_")

			$CommandLineParts = @()
			#Build Command Line
			foreach($Channel in $ChannelMapObject.tracks){
				if($Channel.enable -eq $null -or $Channel.enable -eq $true){
                    $trackFileName = $Channel.track.Replace(" ", "_")
                    if($FileNameList.Keys -notcontains $trackFileName){
                        $FileNameList.Add($trackFileName,@($OutFilenamePrefix))
                    }
                    else{
                        $FileNameList.$trackFileName += $OutFilenamePrefix
                    }

					$outFile = [string]::Format("{0}.{1}.wav", $OutFilenamePrefix, $trackFileName)
					$fulloutFilePath = Join-Path $WorkingDirectory $outFile
					if($Force -or !(Test-Path $fulloutFilePath)){

						$commandSnippet = @()
						foreach($audioChannel in $Channel.channels | Sort-Object){
							$actualChannel = $audioChannel - 1
							$commandSnippet += [string]::Format("-map_channel 0.0.{0}", $actualChannel)
						}

						$channelcommands = [string]::Join(" ", $commandSnippet)


						$channelCommand = [string]::Format("{0} {1} {2}", $channelcommands, "-acodec pcm_s32le", $outFile)
						Write-Debug $channelCommand

						$CommandLineParts += $channelCommand
					}
				}
			}
            if($CommandLineParts -and $CommandLineParts.Count -gt 0){
			    $fullCommandParts = [string]::Join(" ", $CommandLineParts)

			    $fullCommand = [string]::Format('-i "{0}" {1}', $FileName, $fullCommandParts)

			    Write-Verbose "Execute: $FFMpegPath $fullCommand"
                if($TestRun){
                    Write-Host "Execute: $FFMpegPath $fullCommand"
                }
                else{
                    if($procList.Count -ge $MaxFFMpegProcesses){
                        Write-Host "Maximum prceoWaiting for ffmpeg processes to complete"
                        $procList | Wait-Process
                    }
                    $procList += Start-Process -FilePath $FFMpegPath -ArgumentList $fullCommand -WorkingDirectory $WorkingDirectory -PassThru
                }
			    
            }
		}
        Write-Host "Waiting for ffmpeg processes to complete"
        $procList | Wait-Process

        $procList = @()
        foreach($trackName in $FileNameList.Keys){
            $outFile = [string]::Format("{0}.wav", $trackName)
            $finalFulloutFilePath = Join-Path $OutputPath $outFile

            $outConcatFile = [string]::Format("{0}.txt", $trackName)
            $concatTempTextFile = Join-Path $WorkingDirectory $outConcatFile
            if($Force -or !(Test-Path $finalFulloutFilePath)){

                $concatParts = @()

                foreach($trackParts in $FileNameList.$trackName | Sort-Object){
                    $outFile = [string]::Format("{0}.{1}.wav", $trackParts, $trackName)
                    $fullinputFilePath = Join-Path $WorkingDirectory $outFile
                    if((Test-Path $fullinputFilePath) -or $TestRun){
                        $concatParts += "file '$outFile'"

                    }
                    else{
                        Throw "error part missing"
                        #todo
                    }

                }

                $fullConcatCommandParts = [string]::Join("`r`n", $concatParts)

                Set-Content -Path $concatTempTextFile -Value $fullConcatCommandParts -Force
                $fullConcatCommand = [string]::Format("-f concat -safe 0 -i {0} -c copy `"{1}`" -y", $outConcatFile, $finalFulloutFilePath)

			    Write-Verbose "Execute: $FFMpegPath $fullConcatCommand"
                if($TestRun){
                    Write-Host "Execute: $FFMpegPath $fullConcatCommand"
                }
                else{
			        $procList = Start-Process -FilePath $FFMpegPath -ArgumentList $fullConcatCommand -WorkingDirectory $WorkingDirectory -PassThru -Wait:$SingleThread
                }

            }

        }
        Write-Host "Waiting for ffmpeg processes to complete"
        $procList | Wait-Process


		#ffmpeg.exe -i 00000001.WAV -map_channel 0.0.7 lead.wav -map_channel 0.0.12 -map_channel 0.0.13 keys.wav -map_channel 0.0.0 pom.wav

		#ffmpeg -i multichannelinputfile.mov -map_channel 0.1.0 ch0.wav -map_channel 0.1.1 ch1.wav -map_channel 0.1.2 ch2.wav -map_channel 0.1.3 ch3.wav
	}

}