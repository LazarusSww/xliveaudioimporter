function Create-DefaultAudioChannelMap{
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
  enable: false

- track: Mono32
  channels:
  - 32
  enable: false
'@
	
	Write-Output $ChannelMap
}

function Out-AudioChannels{
	[CmdletBinding()]
	param(
		[Parameter(Position=0,Mandatory=$false,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
		[string]$InputFiles = 'C:\Users\sam.webster\Documents\Cubase Projects\Rain - Fox and Hound Recordings\Import\*.wav',

		[Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
		[string]$OutputPath = 'C:\Users\sam.webster\Documents\Cubase Projects\Rain - Fox and Hound Recordings\Import\output',

		[Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
		[object]$ChannelMapFile,
		
		[Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
		[object]$ChannelMap = $(Get-DefaultAudioChannelMap),

		[Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
		[string]$WorkingDirectory = 'C:\Users\sam.webster\Documents\Cubase Projects\Rain - Fox and Hound Recordings\Import\output',
		
		[Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
		[string]$ffmpegPath = 'C:\Users\sam.webster\Downloads\ffmpeg-20200619-2f59946-win64-static\ffmpeg-20200619-2f59946-win64-static\bin\ffmpeg.exe',
		
		[Parameter(Position=0,Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
		[switch]$Force
	)
	begin{
        if(!(Test-Path $ffmpegPath)){
			Write-Error "FFMpeg path '$ffmpegPath' not found." -ErrorAction Stop
		}
		if(!(Test-Path $([System.IO.Path]::GetDirectoryName($InputFiles)))){
			Write-Error "Input folder '$([System.IO.Path]::GetDirectoryName($Input))' not found." -ErrorAction Stop
		}
		if(!(Test-Path $OutputPath)){
			Write-Error "Output folder '$OutputPath' not found." -ErrorAction Stop
		}


        $ChannelMapObject = $ChannelMap

        if($ChannelMap -is [string]){
            $ChannelMapObject = $ChannelMap | ConvertFrom-Yaml
        }

        if(!$ChannelMapObject -or !$ChannelMapObject.tracks){
            Write-Error "Channel map not in correct format." -ErrorAction Stop
        }

	}
	process{
		$Files = Get-ChildItem -Path $InputFiles

        $FileNameList = @{}
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
					$fulloutFilePath = Join-Path $OutputPath $outFile
					if($Force -or !(Test-Path $fulloutFilePath)){
				
						$commandSnippet = @()
						foreach($audioChannel in $Channel.channels | Sort-Object){
							$actualChannel = $audioChannel - 1
							$commandSnippet += [string]::Format("-map_channel 0.0.{0}", $actualChannel)
						}
						
						$channelcommands = [string]::Join(" ", $commandSnippet)
						
						
						$channelCommand = [string]::Format("{0} {1} {2}", $channelcommands, "-acodec pcm_s32le", $outFile)
						Write-Verbose $channelCommand
						
						$CommandLineParts += $channelCommand
					}
				}
			}
            if($CommandLineParts -and $CommandLineParts.Count -gt 0){
			    $fullCommandParts = [string]::Join(" ", $CommandLineParts)	
		
			    $fullCommand = [string]::Format('-i "{0}" {1}', $FileName, $fullCommandParts)

			    Write-Verbose "Execute: $ffmpegPath $fullCommand"
			    Start-Process -FilePath $ffmpegPath -ArgumentList $fullCommand -WorkingDirectory $OutputPath -Wait -PassThru
			
			    #Write-Host $s
            }
		}

        foreach($trackName in $FileNameList.Keys){
            

            $outFile = [string]::Format("{0}.wav", $trackName)
            $outPath = [System.IO.Path]::GetDirectoryName($InputFiles)
            $finalFulloutFilePath = Join-Path $outPath $outFile

            $outConcatFile = [string]::Format("{0}.txt", $trackName)
            $concatTempTextFile = Join-Path $OutputPath $outConcatFile
            if($Force -or !(Test-Path $finalFulloutFilePath)){

                $concatParts = @()
                
                foreach($trackParts in $FileNameList.$trackName | Sort-Object){
                    $outFile = [string]::Format("{0}.{1}.wav", $trackParts, $trackName)
                    $fullinputFilePath = Join-Path $OutputPath $outFile
                    if((Test-Path $fullinputFilePath)){
                        $concatParts += "file '$outFile'"

                    }
                    else{
                        Throw "error part missing"
                        #todo
                    }

                }

                $fullConcatCommandParts = [string]::Join("`r`n", $concatParts)

                
                Set-Content -Path $concatTempTextFile -Value $fullConcatCommandParts -Force
               

                #$fullConcatCommandParts = [string]::Join("|", $concatParts)
		
			    #$fullConcatCommand = [string]::Format("-i `"concat:{0}`" -c copy '{1}'", $fullConcatCommandParts, $finalFulloutFilePath)
                $fullConcatCommand = [string]::Format("-f concat -safe 0 -i {0} -c copy `"{1}`" -y", $outConcatFile, $finalFulloutFilePath)

                #ffmpeg -f concat -safe 0 -i mylist.txt -c copy output.wav

			    Write-Verbose "Execute: $ffmpegPath $fullConcatCommand"
			    $p = Start-Process -FilePath $ffmpegPath -ArgumentList $fullConcatCommand -WorkingDirectory $OutputPath -Wait -PassThru

                   #ffmpeg -i "concat:input1.ts|input2.ts|input3.ts" -c copy output.ts
                #Write-Verbose $p

            }



        }
        

		#>C:\Users\sam.webster\Downloads\ffmpeg-20200619-2f59946-win64-static\ffmpeg-20200619-2f59946-win64-static\bin\ffmpeg.exe -i 00000001.WAV -map_channel 0.0.7 lead.wav -map_channel 0.0.12 -map_channel 0.0.13 keys.wav -map_channel 0.0.0 pom.wav

		#ffmpeg -i multichannelinputfile.mov -map_channel 0.1.0 ch0.wav -map_channel 0.1.1 ch1.wav -map_channel 0.1.2 ch2.wav -map_channel 0.1.3 ch3.wav
	}

}

#Out-AudioChannels -InputFiles 'C:\Users\sam.webster\Documents\Cubase Projects\Rain - Fox and Hound Recordings\Import\00000002.WAV' -ffmpegPath 'C:\Users\sam.webster\Downloads\ffmpeg-20200619-2f59946-win64-static\ffmpeg-20200619-2f59946-win64-static\bin\ffmpeg.exe'