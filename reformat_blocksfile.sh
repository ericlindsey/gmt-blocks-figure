#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Usage: ./reformat_segment.sh <input_file> <output_file> <number_of_lines>"
    echo "For Mod.segment, number of lines is 13. For Strain.block, it's 8."
    exit 1
fi

input_file="$1"
output_file="$2"
number_of_lines="$3"

# Read the header from the input file
header=$(head -n "$number_of_lines" "$input_file" | tr '\n' ' ' | tr -s ' ' | sed 's/ $//')

# Write the header to the output file
echo "$header" > "$output_file"

# Count the total number of lines in the input file
total_lines=$(wc -l < "$input_file")

# Process the input file and append the data to the output file
start_line=$((number_of_lines + 1))
while [ $start_line -le $total_lines ]; do
    end_line=$((start_line + number_of_lines - 1))

    # Extract the block of lines and reformat it
    block=$(sed -n "${start_line},${end_line}p" "$input_file" | tr '\n' ' ' | tr -s ' ' | sed 's/ $//')

    # Append the reformatted block to the output file
    echo "$block" >> "$output_file"

    # Update the start_line for the next iteration
    start_line=$((end_line + 1))
done

