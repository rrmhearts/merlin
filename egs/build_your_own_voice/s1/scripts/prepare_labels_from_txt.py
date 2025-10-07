################################################################################
#
#   SCRIPT NAME: prepare_labels.py (assumed)
#   AUTHOR:      Ryan McCoppin
#
#   DESCRIPTION:
#       A top-level orchestration script for preparing Merlin-compatible label
#       files from raw text. It automates the entire front-end pipeline by
#       sequentially calling a series of tools:
#
#       1. Generates a Festival Scheme script from input text.
#       2. Executes Festival to create utterance (.utt) files.
#       3. Runs the 'make_labels' script to convert .utt files to .lab files
#          (using dumpfeats).
#       4. Normalizes the final label files for use in Merlin training or
#          synthesis.
#
#   USAGE:
#       python prepare_labels.py <path_to_text_dir> <output_lab_dir> \
#                                <path_to_global_config> [--train]
#
################################################################################

import argparse
import os, sys
import subprocess
from argparse import Namespace
from dotenv import load_dotenv, find_dotenv

def prepare_labels(inp_txt, lab_dir, global_config_file, train=False):
    # Load global variables first
    load_dotenv(find_dotenv())

    # Load egs/**/conf second
    if isinstance(global_config_file, dict):
        os.environ.update(global_config_file)
    else:
        # Check if global configuration file exists
        if not os.path.isfile(global_config_file):
            print("Global config file doesn't exist")
            sys.exit(1)

        # Load global configuration
        with open(global_config_file, 'r') as f:
            for line in f:
                if "=" in line: #line.startswith('export '):
                    key, value = line[7:].strip().split('=')
                    os.environ[key] = value

    # Check if festival directory exists
    if 'FESTDIR' not in os.environ or not os.path.isdir(os.environ['FESTDIR']):
        print("Please configure festival path in global configuration file")
        return

    # Define variables
    frontend = os.path.join(os.environ['MerlinDir'], 'misc', 'scripts', 'frontend')
    out_dir = lab_dir

    if train:
        file_id_scp = 'file_id_list.scp'
        scheme_file = 'train_sentences.scm'
    else:
        file_id_scp = 'test_id_list.scp'
        scheme_file = 'new_test_sentences.scm'

    sys.path.insert(2, os.path.join(frontend, 'utils'))
    import genScmFile as gf
    import normalize_lab_for_merlin as nlm

    # Generate scheme file
    # print("Generating scheme file")
    gf.generateScmFile(inp_txt,
        os.path.join(out_dir, 'prompt-utt'),
        os.path.join(out_dir, scheme_file),
        os.path.join(out_dir, file_id_scp),
    )

    # Generate utt from scheme file
    # print("Generating utts from scheme file")
    result = subprocess.run([
        os.path.join(os.environ['FESTDIR'], 'bin', 'festival'),
        '-b',
        os.path.join(out_dir, scheme_file)
    ])

    if result.returncode == 0:
        print("Festival ran on scheme file.!")
    else:
        print("Command failed with return code:", result.returncode)
        print("Error message:", result.stderr)
        exit(1)

    # Convert festival utt to lab
    # print("Converting festival utts to labels")
    subprocess.run([
        os.path.join(frontend, 'festival_utt_to_lab', 'make_labels'),
        os.path.join(out_dir, 'prompt-lab'),
        os.path.join(out_dir, 'prompt-utt'),
        os.path.join(os.environ['FESTDIR'], 'examples', 'dumpfeats'),
        os.path.join(frontend, 'festival_utt_to_lab')
    ])

    # Normalize lab for merlin
    # print("Normalizing label files for merlin")
    if train:
        nlm.normalize_lab_merlin(
            os.path.join(out_dir, 'prompt-lab', 'full'),
            os.path.join(out_dir, 'label_no_align'),
            'phone_align',
            os.path.join(out_dir, file_id_scp),
            '0')
        # Remove unnecessary files
        subprocess.run(['rm', '-rf', os.path.join(out_dir, 'prompt-lab')])
    else:
        nlm.normalize_lab_merlin(
            os.path.join(out_dir, 'prompt-lab', 'full'),
            os.path.join(out_dir, 'prompt-lab'),
            os.environ['Labels'],
            os.path.join(out_dir, file_id_scp),
            '0')
        # Remove unnecessary files
        subprocess.run(['rm', '-rf', os.path.join(out_dir, 'prompt-lab', 'full')])

    print("Labels are ready in:", os.path.join(out_dir, 'prompt-lab'))

if __name__ == '__main__':
    # Parse command line arguments
    # if global_config_file is None:
    parser = argparse.ArgumentParser(description='Prepare labels from text')
    parser.add_argument('inp_txt', help='Path to text directory')
    parser.add_argument('lab_dir', help='Path to label directory')
    parser.add_argument('global_config_file', help='Path to global configuration file')
    parser.add_argument('--train', action='store_true', help='Train mode')
    args = parser.parse_args()

    # else:
    #     args = Namespace(inp_txt=inp_txt, lab_dir=lab_dir, global_config_file=global_config_file, train=train)
    #     if isinstance(global_config_file, dict):
    #         os.environ.update(global_config_file)

    prepare_labels(args.inp_txt, args.lab_dir, args.global_config_file, args.train)
