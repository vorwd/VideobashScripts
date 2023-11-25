
# Overview of **ffmpeg_Eng-Audio-to-ACC-2CH.sh**
  - Applies to .mkv and .mp4 files (could be updated to action against any video file that is supposed by ffmpeg, but I only use it for these two formats)
  - Creates a (very) verbose log file of conversion outcomes and produces a .json file of the ffprobe completed after the conversion is completed
1. Asks the user what directory to action upon
2. Maps all files matching the formats within that directory
3. Creates a temp directory for the file conversion and to store the log and .json files <br>
  3a. The temp directory is for my use-case, as I want to limit the back and forth data transfer on the network until the conversion is completed.
4. Archives old logs and .json files that are older than 24 hours
5. Identifies files already converted by this script by way of the -AC2 notation that gets appended to completed files <br>
  5a. Excludes those files identified as already having this script ran against them
6. Lists filtered (to-be converted) files (and those that are listed as excluded) and askes the user to confirm they want to continue (y/n)
7. Loops through the filtered file list running the following: <br>
  7a. Runs ffprobe to identify English (eng) language audio streams: <br>
>      ffprobe -show_streams -show_entries "format:stream" -v error -of json "$input_file"
  7b. Dynamically constructs ffmpeg arguments based on ffprobe results <br>
  7c. Runs ffmpeg to complete the conversion of eng audio streams into AC-2channel: <br>
>      ffmpeg -i "$input_file" -c:v copy -c:a aac -b:a 384k -map 0 -ac 2 "${map_audio_args[@]}" "$temp_output_file"
  7d. Runs ffprobe on converted file to ensure outcome as expected (this might be overkill and once confirmed the script is working as expected, can likely be removed)
>      ffprobe -show_streams -show_entries "format:stream" -v error -of json "$temp_output_file"
  7e. Appends -AC2 to orignal filename and constructs $final_output_file <br>
  7f. Moves $temp_output_file to $final_output_file
 >   _final_output_file="${target_directory}/${filename}-AC2.${extension}" where ${target_directory} is the original file path provided by the user during step 1_ <br>
8. Finishs log file, sleeps for 2 seconds in case someone is watching the shell, outputs notice to the shell regarding excluded files and conversion completed (noting the log file and the ffprobe AC2.json file location)
<br>
<br>

# Overview of **mkvMerge-Eng-Only.sh**
  - Pending overview
