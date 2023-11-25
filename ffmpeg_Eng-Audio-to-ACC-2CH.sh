#!/bin/bash

# Outline of script to the user
echo -e "\n"
printf "This is a script to convert audio streams within .mkv and .mp4 video files to AC2"
echo -e "\n"

# Get target directory from user input
read -p "Enter the target directory (leave empty for current directory): " target_directory

# Use current directory if target_directory is empty
target_directory=${target_directory:-.}

# Get absolute path of the target directory
target_directory=$(realpath "$target_directory")

# Get all mp4 and mkv files recursively in the target directory
mapfile -d $'\0' files < <(find "$target_directory" -type f -name "*.mp4" -o -name "*.mkv" -print0)

# Ensure the list of files is not empty
if [ "${#files[@]}" -eq 0 ]; then
  echo "No .mp4 or .mkv files found in the specified directory or its subdirectories."
  exit 1
fi

# Temp directory
temp_directory="/home/user/.ffmpeg_tmp/ac2"

# Ensure the temporary directory exists
mkdir -p "$temp_directory"

# Create log_archive directory if it doesn't exist
logarchive_directory="$temp_directory/logarchive"
mkdir -p "$logarchive_directory"

# Move log and .json files older than 3 days to logarchive
find "$temp_directory" -name "*.txt" -or -name "*.json" -mtime +3 -exec mv {} "$logarchive_directory" \;
echo -e "\n"
echo "Moving old log files and .json outputs into $logarchive_directory" 
echo "Please refer to the aforementioned location any artefacts older than 24 hours."
echo -e "\n"

# Exclude files that already have -AC2 appended
filtered_files=()
excluded_files=()
for file in "${files[@]}"; do
  filename=$(basename -- "$file")
  if [[ "$filename" != *"-AC2"* ]]; then
    filtered_files+=("$file")
  else
    excluded_files+=("$file")
  fi
done

# Get the current date and time
current_datetime=$(date +'%Y-%m-%d_%H:%M')

# Log file with date and time
log_file="${temp_directory}/AC2_log_${current_datetime}.txt"

# JSON file for ffprobe results
json_file="${temp_directory}/AC2_ffprobe_${current_datetime}.json"

# Redirect all commands into the log file
exec > >(tee -a "$log_file") 2>&1

# List found files and excluded files
echo -e "\n"
echo "Found files:"
printf "%s\n" "${filtered_files[@]}"
echo -e "\n"

if [ "${#excluded_files[@]}" -gt 0 ]; then
  echo -e "\n"
  echo "Excluded files (already listed as -AC2 in filename):"
  printf "%s\n" "${excluded_files[@]}"
  echo -e "\n"
fi

# Ask for confirmation to proceed with conversion
read -p "Do you want to proceed with converting these files? (y/n): " choice

if [ "$choice" != "y" ]; then
  echo "Conversion aborted."
  exit 1
fi

#-----START OF LOOP-----#
#-----START OF LOOP-----#
#-----START OF LOOP-----#

# Loop through each file
for file in "${filtered_files[@]}"; do
  # Get absolute path of the input file
  input_file=$(realpath "$file")

  # Extract file name and extension
  filename=$(basename -- "$input_file")
  extension="${filename##*.}"
  filename="${filename%.*}"

  # Construct temporary output file path with -AC2 appended
  temp_output_file="${temp_directory}/${filename}-AC2.${extension}"

  # Print the ffprobe command before executing
  echo -e "\n"
  echo "++++ START OF LOG FOR $filename ++++"
  echo -e "\n"
  echo "Running ffprobe command:"
  echo "ffprobe -show_streams -show_entries "format:stream" -v error -of json "$input_file")"

  # Run ffprobe command to gather information about streams
  ffprobe_output=$(ffprobe -show_streams -show_entries "format:stream" -v error -of json "$input_file")

  # Check if ffprobe command was successful
  if [ $? -eq 0 ]; then
    # Extract language tags of audio streams with "eng" language
    eng_audio_streams=$(echo "$ffprobe_output" | jq -r '.streams[] | select(.codec_type == "audio" and .tags.language == "eng") | .index')
      # Write details to the log file for the -AC2 file
      echo -e "\n"
      echo "ffprobe RESULTS OF ++ORIGINAL++ FILE:"
      echo "File: $filename-ORIGINAL"
      echo "$ffprobe_output" | jq -r '.streams[] | "Index: \(.index)\nCodec Name: \(.codec_long_name)\nCodec Type: \(.codec_type)\nLanguage: \(.tags.language)\nAudio Channels: \(.channels)\nChanngel Layout: \(.channel_layout)\n\n"'
      echo -e "\n"
      echo "Initiating ffmpeg command... Please wait, as the shell will not update until after remux is completed...."
    else
      echo "Error in gathering information via ffprobe for $filename-ORIGINAL."
    fi

# Construct the map argument dynamically based on language tags for audio streams
map_audio_args=()
for index in $eng_audio_streams; do
  lang=$(echo "$ffprobe_output" | jq -r ".streams[] | select(.index == $index and .codec_type == \"audio\") | .tags.language")
  if [ "$lang" == "eng" ]; then
    map_audio_args+=("-map" "0:$index")
  fi
done

    # Run ffmpeg command to create the temporary output file
    ffmpeg_output=$(ffmpeg -i "$input_file" -c:v copy -c:a aac -b:a 384k -map 0 -ac 2 "${map_audio_args[@]}" "$temp_output_file" 2>&1)

    # Append ffmpeg output to the log file
    echo -e "\n"
    echo "ffmpeg output:"
    echo "$ffmpeg_output"


    # Check if ffmpeg command was successful
    if [ $? -eq 0 ]; then
      echo -e "\n"
      echo "ffmpeg conversion successful. Temp output: $temp_output_file"
      echo "Initiating ffprobe on -AC2 file..."

      # Run ffprobe command on the -AC2 file and add information to the log file
      ffprobe_output_ac2=$(ffprobe -show_streams -show_entries "format:stream" -v error -of json "$temp_output_file")

      # Save full ffprobe-AC2 output to JSON file
      echo "$filename-AC2 ffprobe full output: " >> "$json_file"
      echo "$ffprobe_output_ac2" >> "$json_file"

      # Check if ffprobe command was successful
      if [ $? -eq 0 ]; then
        # Write details to the log file for the -ac2 file
        echo -e "\n"
        echo "ffprobe RESULTS OF ++CONVERTED++ FILE:"
        echo "File: $filename-AC2"
        echo "$ffprobe_output_ac2" | jq -r '.streams[] | "Index: \(.index)\nCodec Name: \(.codec_long_name)\nCodec Type: \(.codec_type)\nLanguage: \(.tags.language)\nAudio Channels: \(.channels)\nChanngel Layout: \(.channel_layout)\n\n"'
        echo -e "\n"
        echo "Triggering move command to transfer $filename-AC2 to target directory... please wait, this might take a moment depending on file size..."
      else
        echo "Error in gathering information via ffprobe for $filename-AC2."
      fi

      # Construct final output file path with -AC2 appended
      final_output_file="${target_directory}/${filename}-AC2.${extension}"

      # Move the temporary output file to the final destination
      mv "$temp_output_file" "$final_output_file"

      echo "Moved $temp_output_file to $final_output_file"
      echo -e "\n"
    else
      echo -e "\n"
      echo "Error converting $filename."
      printf "%q " "${map_audio_args[@]}"
      echo "$ffmpeg_output"
      echo -e "\n"
      continue  # Move on to the next file if an error occurs
    fi
echo "++++ END OF LOG FOR $filename-AC2 ++++"

  # Sleep to observe the output in shell before proceeding to the next file
  sleep 2
done

# Display a message about excluded files
if [ "${#excluded_files[@]}" -gt 0 ]; then
  echo -e "\nExcluded files (already listed as -AC2 in filename):"
  printf "%s\n" "${excluded_files[@]}"
fi

echo -e "\nConversion complete. Log file: $log_file"
echo -e "\nFull ffprobe output for each -AC2 file saved to: $json_file"
