# merlin_tools.py
# A Python library for automating Merlin TTS toolkit workflows.

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Literal

# --- Main Helper Class ---

class MerlinConfig:
    """A helper class to load and provide typed access to Merlin's global config."""
    def __init__(self, global_config_path: Path):
        if not global_config_path.is_file():
            raise FileNotFoundError(f"Global config file not found: {global_config_path}")
        
        self._config = self._parse_global_config(global_config_path)

    def _parse_global_config(self, config_path: Path) -> Dict[str, str]:
        config = {}
        with open(config_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    key, value = line.split('=', 1)
                    config[key.strip()] = value.strip().strip("'\"")
        return config

    def __getattr__(self, name: str):
        # Allow accessing config values like an attribute, e.g., config.Voice
        key_map = {
            'work_dir': 'WorkDir', 'merlin_dir': 'MerlinDir', 'voice': 'Voice',
            'labels': 'Labels', 'question_file': 'QuestionFile', 'vocoder': 'Vocoder',
            'sampling_freq': 'SamplingFreq', 'silence_phone': 'SilencePhone',
            'file_id_list': 'FileIDList', 'train_files': 'Train', 'valid_files': 'Valid',
            'test_files': 'Test', 'htk_dir': 'HTKDIR', 'fest_dir': 'FESTDIR',
            'festvox_dir': 'FESTVOXDIR'
        }
        if name in key_map:
            try:
                value = self._config[key_map[name]]
                if name == 'sampling_freq':
                    return int(value)
                if name.endswith('_dir'):
                    return Path(value)
                return value
            except KeyError:
                raise AttributeError(f"'{key_map[name]}' not found in global config.")
        raise AttributeError(f"'{name}' is not a valid config attribute.")

# --- Private Helper Functions ---

def _run_command(command: List[str], cwd: Path = None, check: bool = True):
    """A helper to run external commands and handle errors."""
    print(f"Executing: {' '.join(command)}" + (f" in {cwd}" if cwd else ""))
    try:
        process = subprocess.run(
            command,
            cwd=str(cwd) if cwd else None,
            check=check,
            text=True,
            capture_output=True
        )
        if process.stdout:
            print(process.stdout)
        if process.stderr:
            print(process.stderr, file=sys.stderr)
    except FileNotFoundError as e:
        print(f"Error: Command not found: {e.filename}. Is it in your PATH?", file=sys.stderr)
        raise
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {' '.join(command)}", file=sys.stderr)
        print(f"Return code: {e.returncode}", file=sys.stderr)
        print(f"STDOUT:\n{e.stdout}", file=sys.stderr)
        print(f"STDERR:\n{e.stderr}", file=sys.stderr)
        raise

def _apply_substitutions(file_path: Path, substitutions: Dict[str, str]):
    """Reads a file, applies regex substitutions, and writes it back."""
    content = file_path.read_text()
    for pattern, replacement in substitutions.items():
        content = re.sub(pattern, replacement, content)
    file_path.write_text(content)
    
def _get_acoustic_substitutions(cfg: MerlinConfig) -> Dict[str, str]:
    """Helper to generate the complex acoustic setting substitutions."""
    ac_subs = {}
    
    if cfg.labels == "state_align": ac_subs[r"subphone_feats\s*:\s*.*"] = "subphone_feats: full"
    elif cfg.labels == "phone_align": ac_subs[r"subphone_feats\s*:\s*.*"] = "subphone_feats: coarse_coding"

    if cfg.vocoder == "STRAIGHT":
        ac_subs.update({r"bap\s*:\s*.*": "bap: 25", r"dbap\s*:\s*.*": "dbap: 75"})
    elif cfg.vocoder == "WORLD":
        if cfg.sampling_freq == 16000: ac_subs.update({r"bap\s*:\s*.*": "bap: 1", r"dbap\s*:\s*.*": "dbap: 3"})
        elif cfg.sampling_freq == 48000: ac_subs.update({r"bap\s*:\s*.*": "bap: 5", r"dbap\s*:\s*.*": "dbap: 15"})

    if cfg.sampling_freq == 16000:
        ac_subs.update({r"framelength\s*:\s*.*": "framelength: 1024", r"minimum_phase_order\s*:\s*.*": "minimum_phase_order: 511", r"fw_alpha\s*:\s*.*": "fw_alpha: 0.58"})
    elif cfg.sampling_freq == 22050:
        ac_subs.update({r"framelength\s*:\s*.*": "framelength: 1024", r"minimum_phase_order\s*:\s*.*": "minimum_phase_order: 511", r"fw_alpha\s*:\s*.*": "fw_alpha: 0.65"})
    elif cfg.sampling_freq == 44100:
        ac_subs.update({r"framelength\s*:\s*.*": "framelength: 2048", r"minimum_phase_order\s*:\s*.*": "minimum_phase_order: 1023", r"fw_alpha\s*:\s*.*": "fw_alpha: 0.76"})
    elif cfg.sampling_freq == 48000:
        if cfg.vocoder == "WORLD": ac_subs.update({r"framelength\s*:\s*.*": "framelength: 2048", r"minimum_phase_order\s*:\s*.*": "minimum_phase_order: 1023"})
        else: ac_subs.update({r"framelength\s*:\s*.*": "framelength: 4096", r"minimum_phase_order\s*:\s*.*": "minimum_phase_order: 2047"})
        ac_subs[r"fw_alpha\s*:\s*.*"] = "fw_alpha: 0.77"

    if "demo" in cfg.voice:
        ac_subs.update({r"hidden_layer_size\s*:\s*.*": "hidden_layer_size: [512, 512, 512, 512]", r"hidden_layer_type\s*:\s*.*": "hidden_layer_type: ['TANH', 'TANH', 'TANH', 'TANH']"})
        
    return ac_subs

def _prepare_txt_done_data_file(txt_dir, out_file):
    out_f = open(out_file,'w')

    for txtfile in os.listdir(txt_dir):
        if txtfile is not None:
            file_id = os.path.basename(txtfile).split(".")[0]
            txtfile = os.path.join(txt_dir, txtfile)
            with open(txtfile, 'r') as myfile:
                data = myfile.read().replace('\n', '')
            data = data.replace('"', '\\"')
            out_f.write("( "+file_id+" \" "+data+" \")\n")

    out_f.close()

# --- Unified Public API Function for Config Generation ---

def prepare_configs(global_config_path: Path, mode: Literal['training', 'synthesis']):
    """
    Generates duration and acoustic config files for a given mode.
    This single function replaces both prepare_training_configs and prepare_synthesis_configs.
    """
    print(f"\n--- Preparing configurations for {mode} ---")
    cfg = MerlinConfig(global_config_path)

    # Determine file names based on mode
    if mode == 'training':
        dur_conf_file = cfg.work_dir / f"conf/duration_{cfg.voice}.conf"
        ac_conf_file = cfg.work_dir / f"conf/acoustic_{cfg.voice}.conf"
    elif mode == 'synthesis':
        dur_conf_file = cfg.work_dir / f"conf/test_dur_synth_{cfg.voice}.conf"
        ac_conf_file = cfg.work_dir / f"conf/test_synth_{cfg.voice}.conf"
    else:
        raise ValueError("Mode must be 'training' or 'synthesis'")

    # --- Duration Configuration ---
    dur_template = cfg.work_dir / "conf/general/duration_demo.conf"
    if not dur_template.is_file(): dur_template = cfg.merlin_dir / "misc/recipes/duration_demo.conf"
    shutil.copy(dur_template, dur_conf_file)

    base_subs = {
        r"Merlin\s*:\s*.*": f"Merlin: {cfg.merlin_dir}",
        r"TOPLEVEL\s*:\s*.*": f"TOPLEVEL: {cfg.work_dir}",
        r"file_id_list\s*:\s*.*": f"file_id_list: %(data)s/{cfg.file_id_list}",
        r"silence_pattern\s*:\s*.*": f"silence_pattern: ['*-{cfg.silence_phone}+*']",
        r"label_type\s*:\s*.*": f"label_type: {cfg.labels}",
        r"question_file_name\s*:\s*.*": f"question_file_name: %(Merlin)s/misc/questions/{cfg.question_file}",
        r"train_file_number\s*:\s*.*": f"train_file_number: {cfg.train_files}",
        r"valid_file_number\s*:\s*.*": f"valid_file_number: {cfg.valid_files}",
        r"test_file_number\s*:\s*.*": f"test_file_number: {cfg.test_files}",
    }
    
    dur_subs = base_subs.copy()
    dur_subs[r"work\s*:\s*.*"] = f"work: %(TOPLEVEL)s/experiments/{cfg.voice}/duration_model"
    if cfg.labels == "state_align": dur_subs[r"dur\s*:\s*.*"] = "dur: 5"
    elif cfg.labels == "phone_align": dur_subs[r"dur\s*:\s*.*"] = "dur: 1"

    if mode == 'training':
        dur_subs[r"label_align\s*:\s*.*"] = f"label_align: %(TOPLEVEL)s/experiments/{cfg.voice}/duration_model/data/label_{cfg.labels}"
    else: # synthesis mode
        dur_subs.update({
            r"label_align\s*:\s*.*": f"label_align: %(TOPLEVEL)s/experiments/{cfg.voice}/test_synthesis/prompt-lab",
            r"test_id_list\s*:\s*.*": f"test_id_list: %(TOPLEVEL)s/experiments/{cfg.voice}/test_synthesis/test_id_list.scp",
            r"test_synth_dir\s*:\s*.*": f"test_synth_dir: %(TOPLEVEL)s/experiments/{cfg.voice}/test_synthesis/gen-lab",
            r"DurationModel\s*:\s*.*": "DurationModel: True", "GenTestList\s*:\s*.*": "GenTestList: True",
            r"NORMLAB\s*:\s*.*": "NORMLAB: True", "MAKEDUR\s*:\s*.*": "MAKEDUR: False",
            r"MAKECMP\s*:\s*.*": "MAKECMP: False", "NORMCMP\s*:\s*.*": "NORMCMP: False",
            r"TRAINDNN\s*:\s*.*": "TRAINDNN: False", "CALMCD\s*:\s*.*": "CALMCD: False",
            r"DNNGEN\s*:\s*.*": "DNNGEN: True",
        })
    if "demo" in cfg.voice:
        dur_subs.update({
            r"hidden_layer_size\s*:\s*.*": "hidden_layer_size: [512, 512, 512, 512]",
            r"hidden_layer_type\s*:\s*.*": "hidden_layer_type: ['TANH', 'TANH', 'TANH', 'TANH']"
        })
    _apply_substitutions(dur_conf_file, dur_subs)
    print(f"{mode.capitalize()} duration configuration saved to {dur_conf_file}")

    # --- Acoustic Configuration ---
    ac_template = cfg.work_dir / "conf/general/acoustic_demo.conf"
    if not ac_template.is_file(): ac_template = cfg.merlin_dir / "misc/recipes/acoustic_demo.conf"
    shutil.copy(ac_template, ac_conf_file)

    ac_subs = base_subs.copy()
    ac_subs.update({
        r"work\s*:\s*.*": f"work: %(TOPLEVEL)s/experiments/{cfg.voice}/acoustic_model",
        r"mgc\s*:\s*.*": "mgc: 60", "dmgc\s*:\s*.*": "dmgc: 180",
        r"lf0\s*:\s*.*": "lf0: 1", "dlf0\s*:\s*.*": "dlf0: 3",
        r"vocoder_type\s*:\s*.*": f"vocoder_type: {cfg.vocoder}",
        r"samplerate\s*:\s*.*": f"samplerate: {cfg.sampling_freq}",
    })
    
    if mode == 'training':
        ac_subs[r"label_align\s*:\s*.*"] = f"label_align: %(TOPLEVEL)s/experiments/{cfg.voice}/acoustic_model/data/label_{cfg.labels}"
    else: # synthesis mode
        ac_subs.update({
            r"label_align\s*:\s*.*": f"label_align: %(TOPLEVEL)s/experiments/{cfg.voice}/test_synthesis/gen-lab",
            r"test_id_list\s*:\s*.*": f"test_id_list: %(TOPLEVEL)s/experiments/{cfg.voice}/test_synthesis/test_id_list.scp",
            r"enforce_silence\s*:\s*.*": "enforce_silence: True",
            r"test_synth_dir\s*:\s*.*": f"test_synth_dir: %(TOPLEVEL)s/experiments/{cfg.voice}/test_synthesis/wav",
            r"AcousticModel\s*:\s*.*": "AcousticModel: True", "GenTestList\s*:\s*.*": "GenTestList: True",
            r"MAKECMP\s*:\s*.*": "MAKECMP: False", "NORMCMP\s*:\s*.*": "NORMCMP: False",
            r"TRAINDNN\s*:\s*.*": "TRAINDNN: False", "CALMCD\s*:\s*.*": "CALMCD: False",
        })

    ac_subs.update(_get_acoustic_substitutions(cfg))
    
    _apply_substitutions(ac_conf_file, ac_subs)
    print(f"{mode.capitalize()} acoustic configuration saved to {ac_conf_file}")

def generate_labels_from_text(text_dir: Path, label_dir: Path, global_config_path: Path, is_training: bool = False):
    """Generates untimed linguistic labels from text files using Festival."""
    print(f"\n--- Generating Labels from Text (Training={is_training}) ---")
    cfg = MerlinConfig(global_config_path)
    frontend_dir = cfg.merlin_dir / "misc/scripts/frontend"
    label_dir.mkdir(parents=True, exist_ok=True)
    
    file_id_scp = "file_id_list.scp" if is_training else "test_id_list.scp"
    scheme_file = "train_sentences.scm" if is_training else "new_test_sentences.scm"

    _run_command([
        sys.executable, str(frontend_dir / "utils/genScmFile.py"),
        str(text_dir), str(label_dir / "prompt-utt"),
        str(label_dir / scheme_file), str(label_dir / file_id_scp)
    ])
    _run_command([str(cfg.fest_dir / "bin/festival"), "-b", str(label_dir / scheme_file)])
    _run_command([
        str(frontend_dir / "festival_utt_to_lab/make_labels"),
        str(label_dir / "prompt-lab"), str(label_dir / "prompt-utt"),
        str(cfg.fest_dir / "examples/dumpfeats"), str(frontend_dir / "festival_utt_to_lab")
    ])

    if is_training:
        py_command = [
            sys.executable, str(frontend_dir / "utils/normalize_lab_for_merlin.py"),
            str(label_dir / "prompt-lab/full"), str(label_dir / "label_no_align"),
            "phone_align", str(label_dir / file_id_scp), "0"
        ]
        _run_command(py_command)
        shutil.rmtree(label_dir / "prompt-lab", ignore_errors=True)
    else:
        py_command = [
            sys.executable, str(frontend_dir / "utils/normalize_lab_for_merlin.py"),
            str(label_dir / "prompt-lab/full"), str(label_dir / "prompt-lab"),
            cfg.labels, str(label_dir / file_id_scp), "0"
        ]
        _run_command(py_command)
        shutil.rmtree(label_dir / "prompt-lab/full", ignore_errors=True)

def run_phone_alignment(global_config_path: Path):
    """
    Performs phone-level forced alignment using FestVox Clustergen. It takes
    audio files and text transcriptions and produces time-aligned phonetic labels.
    
    Corresponds to: run_phone_aligner.txt

    Args:
        wav_dir (Path): Path to the directory containing .wav files.
        text_dir (Path): Path to the directory containing .txt transcription files.
        output_dir (Path): Directory where the final labels will be saved.
        global_config_path (Path): Path to the main global_settings.cfg file.
    """
    print("\n--- Running Phone-level Forced Alignment ---")
    cfg = MerlinConfig(global_config_path)

    wav_dir = cfg.work_dir / "database/wav"
    txt_input = cfg.work_dir / "database/txt.data"
    labels_dir = cfg.work_dir / "database/lab"

    # Create and navigate to the temp build directory
    build_dir = labels_dir / f"cmu_us_{cfg.voice}"
    labels_dir.mkdir(parents=True, exist_ok=True)

    # 1. Setup Clustergen
    _run_command([str(cfg.festvox_dir / "src/clustergen/setup_cg"), "cmu", "us", cfg.voice], cwd=build_dir)

    # 2. Prepare data
    (build_dir / "wav").mkdir(exist_ok=True)
    for wav_file in wav_dir.glob("*.wav"):
        shutil.copy(wav_file, build_dir / "wav")

    # This part converts individual text files or a single data file
    if txt_input.is_file():
        shutil.copy(txt_input, build_dir / "etc/txt.done.data")
    elif txt_input.is_dir():
        _prepare_txt_done_data_file(str(txt_input.resolve()), str(build_dir / "etc/txt.done.data") )
        # _run_command([
        #     sys.executable, str(cfg.merlin_dir / "misc/scripts/frontend/utils/prepare_txt_done_data_file.py"),
        #     str(txt_input.resolve()), str(build_dir / "etc/txt.done.data")
        # ])
    else:
        raise FileNotFoundError(f"Input text data not found at: {txt_input}")

    # 3. Run build steps for alignment
    for step in ["build_prompts", "label", "build_utts"]: 
        _run_command([build_dir / "bin/do_build", step], cwd=build_dir)

    # 4. Generate file_id_list from the txt.done.data file
    file_id_list_path = labels_dir / "file_id_list.scp"
    with open(file_id_list_path, "w") as f_out, \
         open(build_dir / "etc/txt.done.data", "r") as f_in:
        for line in f_in:
            file_id = line.strip().split(" ")[1]
            f_out.write(f"{file_id}\n")

    # 5. Convert utts to labels
    frontend_dir = cfg.merlin_dir / "misc/scripts/frontend"
    _run_command([
        str(frontend_dir / "festival_utt_to_lab/make_labels"),
        "full-context-labels",
        "festival/utts",
        str(cfg.fest_dir / "examples/dumpfeats"),
        str(frontend_dir / "festival_utt_to_lab")
    ], cwd=build_dir.parent)

    # 6. Normalize labels
    _run_command([
        sys.executable, str(frontend_dir / "utils/normalize_lab_for_merlin.py"),
        "full-context-labels/full",
        "label_phone_align",
        "phone_align",
        "file_id_list.scp"
    ], cwd=labels_dir)

    final_dir = labels_dir / "label_phone_align"
    if not final_dir.is_dir() or not any(final_dir.iterdir()):
        print("Error: Phone alignment failed. No labels were generated.", file=sys.stderr)
        raise RuntimeError("Phone alignment process failed to generate output.")
    else:
        print(f"Phone alignment successful. Labels are in: {final_dir}")

def run_state_alignment(global_config_path: Path):
    """Performs state-level forced alignment using the self-configuring forced_alignment.py."""
    print("\n--- Running State-level Forced Alignment ---")
    cfg = MerlinConfig(global_config_path)
    
    aligner_script = cfg.merlin_dir / "misc/scripts/alignment/state_align/forced_alignment.py"
    labels_dir = cfg.work_dir / "database/lab"
    
    # 1. Create untimed labels needed by forced_alignment.py
    generate_labels_from_text(cfg.work_dir / "database/txt.data", labels_dir, global_config_path, is_training=True)
    
    # 2. Run the self-configuring aligner from the correct directory
    _run_command([sys.executable, str(aligner_script)], cwd=cfg.work_dir)

    # 3. Verify output
    final_dir = labels_dir / "label_state_align"
    if not final_dir.is_dir() or not any(final_dir.iterdir()):
        print("Error: State alignment failed to produce output files.", file=sys.stderr)
        raise RuntimeError("State alignment process failed.")
    print(f"State alignment successful. Labels are in: {final_dir}")

def clean_synthesis_files(global_config_path: Path):
    """Removes intermediate files from synthesis directories."""
    print("\n--- Cleaning Intermediate Synthesis Files ---")
    cfg = MerlinConfig(global_config_path)
    synthesis_dir = cfg.work_dir / f"experiments/{cfg.voice}/test_synthesis"
    
    for sub_dir_name in ["gen-lab", "wav"]:
        sub_dir = synthesis_dir / sub_dir_name
        if sub_dir.is_dir():
            for f in sub_dir.iterdir():
                if f.is_file() and f.suffix not in ['.lab', '.wav']:
                    print(f"Removing {f}")
                    f.unlink()
    print("Cleanup complete.")