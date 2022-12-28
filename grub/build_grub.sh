#!/bin/bash

# Set up variables
file=""
grub_config="grub.cfg"

# Use getopts to parse command line options
while getopts ":k:" opt; do
  case $opt in
    k)
      file=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Check if file is set
if [[ -z "$file" ]]; then
  echo "Error: file not specified"
  exit 1
fi

if grub-file --is-x86-multiboot $file; then
  echo multiboot confirmed
else
  echo the file is not multiboot
  exit 1
fi

# Check if file exists
if [[ ! -f $file ]]; then
  echo "Error: file does not exist"
  exit 1
fi

script_path=$(dirname "$(realpath "$0")")
grub_config_path="$script_path/$grub_config"
# Check if file exists
if [[ ! -f $grub_config_path ]]; then
  echo "Error: grub config does not exist"
  exit 1
fi


# Create a temporary directory
temp_dir=$(mktemp -d)
mkdir -p $temp_dir/boot/grub

# Copy the file to the temporary directory
cp $file $temp_dir/boot/unikernel.bin
cp $grub_config_path $temp_dir/boot/grub/grub.cfg

ls $temp_dir
echo "Successfully copied $file to $temp_dir"

grub-mkrescue -o unikernel.iso $temp_dir