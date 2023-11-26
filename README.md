# Tips to acheiving successful outcomes:
I found it works best to complete the mkvMerge-Eng-Only.sh script on the directory/file prior to calling one of the ffmpeg variants.  This is due to the ffmpeg options/arguments I've chosen to call in the script.  You may find better suited options to feed into ffmpeg which would prevent this sort of issue from occuring.  I will work to update the chosen options, while still acheivng a successful outcome, if it becomes a hassle for me to trigger the scripts in this sequence.**
  >  Error initializing output stream 0:3 -- Subtitle encoding currently only possible from text to text or bitmap to bitmap
<br>

_What's strange about this error, is that my $map_audio_args should be excluding subtitles all together and the script should only be working on audio streams -- I did fiddle around with the **jq** outputs of ffprobe-original, which feeds into the $map_audio_args, but didn't resolve it yet_
  
  > map_audio_args=() <br>
      for index in $eng_audio_streams; do <br>
        lang=$(echo "$ffprobe_output" | jq -r ".streams[] | select(.index == $index and .codec_type == \"audio\") | .tags.language") <br>
        if [ "$lang" == "eng" ]; then <br>
          map_audio_args+=("-map" "0:$index") <br>
        fi <br>
      done <br>
<br>

# Overview of **ffmpeg_Eng-Audio-to-ACC-2CH.sh**
  - Applies to .mkv and .mp4 files (could be updated to action against any video format that is supported by **ffmpeg**, but I only use it for these two formats -- feel free to update)
  - Creates a verbose (very/overkill) and timestamped log file of the end-to-end process and produces a timestamped .json file of the ffprobe completed after the conversion is completed
  - Appends -AC2 to the file and preserves the orignal file as-is to allow the user to confirm success before (if they want) disposing of the original.
  - Requires **ffmpeg** to be installed: https://github.com/FFmpeg/FFmpeg <-- don't forget to donate or contribute, if you're able (-:
1. Asks the user what directory to action upon (or actions on the directory the script is run in, if user input is left blank)
2. Maps all files within the **target_directory** that are matching .mkv or .mp4
3. Creates a **temporary_directory** for the file conversion to take place and is where the log and .json files are stored <br>
  3a. The temp directory is for my use-case, as I want to limit the back and forth data transfer on the network until the conversion is completed.  You could comment this out or remove it if your directory is local (or keep it so that the log files are stored somewhere outside of your video file folder)
4. Archives old logs and .json files older than 24 hours
5. Identifies and excludes files already converted by this script by way of the -AC2 notation that is appended to completed files by this script
6. Outputs to the shell, the list of filtered (to-be converted) files (and those listed as excluded) and askes the user to confirm they want to continue (y/n)
7. **Starts Loop** on filtered file list and runs the following: <br>
    7a. Initiates **ffprobe** to identify English (eng) language audio streams: <br>
    >      ffprobe -show_streams -show_entries "format:stream" -v error -of json "$input_file"
    7b. Dynamically constructs **ffmpeg** arguments based on ffprobe results <br>
    7c. Runs **ffmpeg** to complete the conversion of eng audio streams into AC-2channel audio (also a awk pipe to reduce the bloat in the ffmpeg output - remove this pipe if you want it all):
    >      ffmpeg -hide_banner -i "$input_file" -c:v copy -c:a aac -b:a 384k -map 0 -ac 2 "${map_audio_args[@]}" "$temp_output_file" 2>&1 | awk '!/frame=|_STATISTICS_WRITING_|_STATISTICS_TAGS|NUMBER_OF_FRAMES|NUMBER_OF_BYTES/ { print }'
    7d. Runs **ffprobe** on converted file to ensure outcome as expected (this might be overkill and once confirmed the script is working as expected, can likely be removed)
    >      ffprobe -show_streams -show_entries "format:stream" -v error -of json "$temp_output_file"
    7e. Appends -AC2 to orignal filename and constructs $final_output_file <br>
    7f. Moves $temp_output_file to $final_output_file
     > _final_output_file="${target_directory}/${filename}-AC2.${extension}" where ${target_directory} is the original directory path provided by the user during step 1_ <br>
8. Finishs log file, sleeps for 2 seconds in case someone is watching, outputs notices to the shell regarding excluded files not action and if the script completed (noting the log file and the ffprobe AC2.json file location)
<br>
<br>

# Overview of **ffmpeg_Eng-Audio-to-ACC-2CH_MV.sh**
  - Same base functionaly as the original **ffmpeg_Eng-Audio-to-ACC-2CH.sh**
  - In addition, it introduces a new variable **temp_input_file**, as well as a new cp and rm command
    -   Utilises the cp command to copy the "$input_file" into the temporary directory, creating the **temp_input_file**, before the loop starts
    -   After a successful conversion (as well as the existing mv command (among others) to move the $temp_output_file to the $target_directory), employs the rm command to delete the **temp_input_file** from the temporary directory
  -   The addition of the cp and rm commands promote successful outcomes on larger files by aiding in the prevention hangs on the **ffmpeg** converstion due to network latency or dropouts.
<br>
<br>

# Overview of **mkvMerge-Eng-Only.sh**
  - Applies to .mkv files ONLY (could be updated to action against any video format that is supported by **mkvtoolnix** -- feel free to update as you require)
  - Creates a verbose (very/overkill) and timestamped log file of the end-to-end process and produces a timestamped .json file of the **ffprobe** completed after the multiplex is completed
  - Appends -ENG to the file and preserves the orignal file as-is to allow the user to confirm success before (if they want) disposing of the original.
  - Requires **mkvtoolnix** to be installed: https://mkvtoolnix.download/source.html#download <-- don't forget to donate or contribute, if you're able (-:
1. Asks the user what directory to action upon (or actions on the directory the script is run in, if user input is left blank)
2. Maps all files within the **target_directory** that are matching .mkv
3. Creates a **temporary_directory** for the file conversion to take place and is where the log and .json files are stored <br>
  3a. The temp directory is for my use-case, as I want to limit the back and forth data transfer on the network until the conversion is completed.  You could comment this out or remove it if your directory is local (or keep it so that the log files are stored somewhere outside of your video file folder)
4. Archives old logs and .json files older than 24 hours
5. Identifies and excludes files already converted by this script by way of the -ENG notation that is appended to completed files by this script
6. Outputs to the shell, the list of filtered (to-be converted) files (and those listed as excluded) and askes the user to confirm they want to continue (y/n)
7. **Starts Loop** on filtered file list and runs the following: <br>
  7a. Initiates **mkvmerge** (snip 1) and feeds in the input_args (snip 2). <br>
> 
    Snip 1:
  >      mkvmerge -o "$temp_output_file" "${mkvmerge_input_args[@]}" 2>&1 | grep -v "Progress:"
    Snip 2:
  >      mkvmerge_input_args=(-a eng -s eng "$input_file")
  7b. Runs **ffprobe** on converted file to ensure outcome as expected (this might be overkill and once confirmed the script is working as expected, can likely be removed)
  >      ffprobe -show_streams -show_entries "format:stream" -v error -of json "$temp_output_file"
  7c. Appends -ENG to orignal filename and constructs $final_output_file <br>
  7d. Moves $temp_output_file to $final_output_file
   > _final_output_file="${target_directory}/${filename}-AC2.${extension}" where ${target_directory} is the original directory path provided by the user during step 1_ <br>
8. Finishs log file, sleeps for 2 seconds in case someone is watching, outputs notices to the shell regarding excluded files not action and if the script completed (noting the log file and the ffprobe AC2.json file location)
