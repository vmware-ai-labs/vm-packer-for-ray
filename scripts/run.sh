#!/bin/bash
set -o errexit

skip_uploading_iso=false

if [ $# -lt 1 ]; then
    echo "Unexpected: Usage: $0 <packer_dir>"
    exit 1
fi

workdir=$1

# Loop through the command-line arguments
while [[ $# -gt 1 ]]; do
    case "$2" in
        --skip-uploading-iso)
            # Set the skip_uploading_iso variable to true if the parameter is provided
            skip_uploading_iso=true
            shift # Move to the next argument
            ;;
        *)
            # If the argument doesn't match --skip-uploading-iso, skip it
            shift
            ;;
    esac
done

script_dir="${workdir}/scripts"
plugin_dir="${workdir}/plugins"
config_dir="${workdir}/config"
config_input_file="${config_dir}/config.hcl"
config_output_file="${config_dir}/vsphere.pkr.json"

# Create a content library if it doesn't exist
cd "${script_dir}"
python create_content_library.py "${config_input_file}"

# If skip_uploading_iso is not set, then the Debian iso will be uploaded to the datastore automatically.
if [ "$skip_uploading_iso" = true ]; then
    echo "Skipping uploading ISO"
else
    # Run the command to upload the ISO if the parameter is not provided
    python upload_iso.py "${config_input_file}"
fi

# Use the variables in config/config.hcl to overwrite builds/vsphere.pkrvars.hcl, then generate config/vsphere.pkr.json
# packer can also take json file as an input.
python overwrite_vars.py "${config_input_file}" "${config_output_file}"

# Execute the packer commands
cd "${workdir}"
export PACKER_PLUGIN_PATH=${plugin_dir}
packer init builds/linux/debian
packer build -force --only vsphere-iso.linux-debian -var-file="${config_output_file}" builds/linux/debian
cd -