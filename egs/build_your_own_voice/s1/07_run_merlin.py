import sys
import os
import subprocess

# vital for the global use case
file_path = os.path.dirname(__file__)


# UNFINISHED / see build_your_own_voice/cmu_us_aew_arctic for best version!
def load_global_config(global_config_file):
    """Load global configuration from file"""
    config = {}
    with open(os.path.join(file_path, global_config_file), 'r') as f:
        for line in f:
            if "=" in line:
                key, value = line.strip().split('=')
                config[key] = value
    return config

def prepare_labels_from_txt(inp_txt, lab_dir, global_config_file):
    """Run prepare_labels_from_txt.sh script"""
    bash_cmd = f"{file_path}/scripts/prepare_labels_from_txt.sh {inp_txt} {lab_dir} {global_config_file}"
    subprocess.run(bash_cmd, shell=True)

def run_merlin(config_file):
    """Run run_merlin.py script"""
    global_config = load_global_config('conf/global_settings.cfg')
    merlin_dir = global_config['MerlinDir']
    python_cmd = f"python {merlin_dir}/src/run_merlin.py {config_file}"
    subprocess.run(python_cmd, shell=True)

def remove_intermediate_files(global_config_file):
    """Run remove_intermediate_files.sh script"""
    bash_cmd = f"{file_path}/scripts/remove_intermediate_files.sh {global_config_file}"
    subprocess.run(bash_cmd, shell=True)

def main():
    global_config_file = 'conf/global_settings.cfg'
    global_config = load_global_config(global_config_file)

    if len(sys.argv) != 4:
        print("################################")
        print("Usage: ")
        print("python script_name.py <path_to_text_dir> <path_to_test_dur_conf_file> <path_to_test_synth_conf_file>")
        print("")
        print("default path to text dir: experiments/${Voice}/test_synthesis/txt")
        print("default path to test duration conf file: conf/test_dur_synth_${Voice}.conf")
        print("default path to test synthesis conf file: conf/test_synth_${Voice}.conf")
        print("################################")
        sys.exit(1)

    inp_txt = sys.argv[1]
    test_dur_config_file = sys.argv[2]
    test_synth_config_file = sys.argv[3]

    print("Step 7:")
    print("synthesizing speech from text...")

    print("preparing full-contextual labels using Festival frontend...")
    lab_dir = os.path.dirname(inp_txt)
    prepare_labels_from_txt(inp_txt, lab_dir, global_config_file)

    print("synthesizing durations...")
    run_merlin(test_dur_config_file)

    print("synthesizing speech...")
    run_merlin(test_synth_config_file)

    print("deleting intermediate synthesis files...")
    remove_intermediate_files(global_config_file)

    print("synthesized audio files are in: experiments/${Voice}/test_synthesis/wav")
    print("All successful!! Your demo voice is ready :)")

if __name__ == "__main__":
    main()
