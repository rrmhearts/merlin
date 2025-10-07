import sys
import os
import shutil

def load_config_file(config_file):
    """
    Load configuration from a file.
    """
    config = {}
    with open(config_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                key, value = line.split('=')
                config[key.strip()] = value.strip()
    return config

def remove_inter_files(config):
    """
    Remove intermediate synthesis files.
    """
    synthesis_dir = os.path.join(config['WorkDir'], 'experiments', config['Voice'], 'test_synthesis')
    gen_lab_dir = os.path.join(synthesis_dir, 'gen-lab')
    gen_wav_dir = os.path.join(synthesis_dir, 'wav')

    if os.path.isdir(gen_lab_dir):
        for file in os.listdir(gen_lab_dir):
            if not file.endswith('.lab'):
                os.remove(os.path.join(gen_lab_dir, file))

    if os.path.isdir(gen_wav_dir):
        for file in os.listdir(gen_wav_dir):
            if file == 'weight' or not file.endswith('.wav'):
                os.remove(os.path.join(gen_wav_dir, file))

def main():
    if len(sys.argv) != 2:
        print("Usage: python remove_inter_files.py conf/global_settings.cfg")
        sys.exit(1)

    config_file = sys.argv[1]
    if not os.path.isfile(config_file):
        print("Global config file doesn't exist")
        sys.exit(1)

    config = load_config_file(config_file)
    remove_inter_files(config)

if __name__ == "__main__":
    main()
