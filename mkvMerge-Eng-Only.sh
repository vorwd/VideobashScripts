#!/bin/bash

# Outline of script to the user
echo -e "\n"
echo "This is a script to strip non-english subtitle and audio tracks from .mkv files"
echo -e "\n"

# Get target directory from user input
read -p "Enter the target directory (leave empty for the current directory): " target_directory

# Use the current directory if target_directory is empty
target_directory=${target_directory:-.}

# Get the absolute path of the target directory
target_directory=$(realpath "$target_directory")

# Get all mkv files recursively in the target directory
mapfile -d $'\0' files < <(find "$target_directory" -type f -name "*.mkv" -print0)

# Ensure the list of files is not empty
if [ "${#files[@]}" -eq 0 ]; then
  echo "No .mkv files found in the specified directory or its subdirectories."
  exit 1
fi

# Temp directory
temp_directory="/home/user/.ffmpeg_tmp/mkv_eng"

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

# Exclude files that already have -ENG appended
filtered_files=()
excluded_files=()
for file in "${files[@]}"; do
  filename=$(basename -- "$file")
  if [[ "$filename" != *"-ENG"* ]]; then
    filtered_files+=("$file")
  else
    excluded_files+=("$file")
  fi
done

# Get the current date and time
current_datetime=$(date +'%Y-%m-%d_%H:%M')

# Log file with date and time
log_file="${temp_directory}/mkv_log_${current_datetime}.txt"

# JSON file for ffprobe results
json_file="${temp_directory}/ENG_ffprobe_${current_datetime}.json"

# Redirect all commands into the log file
exec > >(tee -a "$log_file") 2>&1

# List found files and excluded files
echo -e "\n"
echo "Found files:"
printf "%s\n" "${filtered_files[@]}"
echo -e "\n"

if [ "${#excluded_files[@]}" -gt 0 ]; then
  echo -e "\n"
  echo "Excluded files (already listed as -ENG in filename):"
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

  # Construct temporary output file path with -ENG appended
  temp_output_file="${temp_directory}/${filename}-ENG.${extension}"

  # Construct mkvmerge input arguments
  mkvmerge_input_args=(-a eng -s eng "$input_file")

  # Print the mkvmerge command before executing
  echo -e "\n"
  echo "++++ START OF LOG FOR $filename ++++"
  echo -e "\n"
  echo "Running mkvmerge command:"
  echo "mkvmerge -o \"$temp_output_file\" ${mkvmerge_input_args[*]/#\"/\"}"
  echo -e "\n"
  echo "Please wait, as the shell will not update until after converting is complete...."

# Run mkvmerge command to create the temporary output file
mkvmerge_output=$(mkvmerge -o "$temp_output_file" "${mkvmerge_input_args[@]}" 2>&1 | grep -v "Progress:")

# Append mkvmerge output to the log file
echo -e "\n"
echo "mkvmerge output:"
echo "$mkvmerge_output"

  # Check if mkvmerge command was successful
  if [ $? -eq 0 ]; then
    echo -e "\n"
    echo "mkvmerge successful. Temp output: $temp_output_file"
    echo "Initiating ffprobe on -ENG file..."

    # Run ffprobe command on the -ENG file and add information to the log file
    ffprobe_output_ENG=$(ffprobe -show_streams -show_entries "format:stream" -v error -of json "$temp_output_file")

    # Save full ffprobe-ENG output to JSON file
    echo "$filename-ENG ffprobe full output: " >> "$json_file"   
    echo "$ffprobe_output_ENG" >> "$json_file"

    # Check if ffprobe command was successful
    if [ $? -eq 0 ]; then
      # Write details to the log file for the -ENG file
      echo -e "\n"
      echo "ffprobe RESULTS OF ++CONVERTED++ FILE:"
      echo "File: $filename-ENG"
      echo "$ffprobe_output_ENG" | jq -r '.streams[] | "Index: \(.index)\nCodec Name: \(.codec_long_name)\nCodec Type: \(.codec_type)\nLanguage: \(.tags.language)\nAudio Channels: \(.channels)\nChanngel Layout: \(.channel_layout)\n\n"'
      echo -e "\n"
      echo "Triggering move command to transfer $filename-ENG to target directory... please wait, this might take a moment depending on file size..."
    else
      echo "Error in gathering information via ffprobe for $filename-ENG."
    fi

    # Construct final output file path with -ENG appended
    final_output_file="${target_directory}/${filename}-ENG.${extension}"

    # Move the temporary output file to the final destination
    mv "$temp_output_file" "$final_output_file"

    echo "Moved $temp_output_file to $final_output_file"
    echo -e "\n"
  else
    echo -e "\n"
    echo "Error converting $filename."
    printf "%q " "${mkvmerge_input_args[@]}"
    echo "$mkvmerge_output"
    echo -e "\n"
    continue  # Move on to the next file if an error occurs
  fi
echo "++++ END OF LOG FOR $filename-ENG ++++"

  # Sleep to observe the output in shell before proceeding to the next file
  sleep 2
done

# Display a message about excluded files
if [ "${#excluded_files[@]}" -gt 0 ]; then
  echo -e "\nExcluded files (already listed as -ENG in filename):"
  printf "%s\n" "${excluded_files[@]}"
fi

echo -e "\nConversion complete. Log file: $log_file"
echo -e "\nFull ffprobe output for each -ENG file saved to: $json_file"
