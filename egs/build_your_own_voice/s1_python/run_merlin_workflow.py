#!/usr/bin/env python3

import argparse
import sys
import os
import shutil
from pathlib import Path
import urllib.request
import zipfile

# Ensure the merlin_tools library is in the Python path
try:
    import merlin_tools
except ImportError:
    print("Error: Ensure 'merlin_tools.py' is in the same directory or Python path.", file=sys.stderr)
    sys.exit(1)

# --- Main Workflow Functions ---

def download_and_setup_data():
    """Downloads and extracts the demo voice data."""
    print("--- Setting up Demo Data ---")
    wav_zip_url = "http://104.131.174.95/downloads/build_your_own_voice/slt_demo/wav.zip"
    txt_data_url = "http://104.131.174.95/downloads/build_your_own_voice/slt_demo/txt.data"
    
    database_dir = Path("database")
    database_dir.mkdir(exist_ok=True)
    wav_zip_path = Path("wav.zip")
    txt_data_path = database_dir / "txt.data"
    
    print(f"Downloading {wav_zip_url}...")
    urllib.request.urlretrieve(wav_zip_url, wav_zip_path)
    
    print(f"Downloading {txt_data_url}...")
    urllib.request.urlretrieve(txt_data_url, txt_data_path)
    
    print(f"Extracting {wav_zip_path} to {database_dir}...")
    with zipfile.ZipFile(wav_zip_path, 'r') as zip_ref:
        zip_ref.extractall(database_dir)
        
    wav_zip_path.unlink() # Clean up the zip file
    print("Data setup complete.")

def setup_project(voice_name: str, test_data: str = "") -> Path:
    """
    Sets up the project structure and global config.
    Corresponds to: 01_setup.sh
    """
    print("\n--- Step 1: Setting up Project ---")
    work_dir = Path.cwd()
    merlin_dir = work_dir.parent.parent.parent
    conf_dir = work_dir / "conf"
    conf_dir.mkdir(exist_ok=True)
    global_config_file = conf_dir / "global_settings.cfg"
    
    # Create directories
    experiments_dir = work_dir / "experiments"
    voice_dir = experiments_dir / voice_name
    synthesis_dir = voice_dir / "test_synthesis"
    
    dirs_to_create = [
        work_dir / "database/lab", # Important for state aligner
        experiments_dir, voice_dir,
        voice_dir / "acoustic_model/data",
        voice_dir / "duration_model/data",
        synthesis_dir / "txt",
    ]
    for d in dirs_to_create:
        d.mkdir(parents=True, exist_ok=True)
    
    # Create test synthesis files
    if test_data:
        for filename in os.listdir(synthesis_dir / "txt"):
            try:
                wav_path = synthesis_dir / "wav" / filename
                os.remove(synthesis_dir / "txt" / filename)
                os.remove(wav_path.with_suffix(".lab"))
                os.remove(wav_path.with_suffix(".wav"))
            except:
                pass
        (synthesis_dir / "txt" / "test.txt").write_text(test_data)
    else:
        # dummy data to test synthesis
        (synthesis_dir / "txt" / "test_001.txt").write_text("Hello world.")
        (synthesis_dir / "txt" / "test_002.txt").write_text("Hi, this is a demo voice from Merlin.")
        (synthesis_dir / "txt" / "test_003.txt").write_text("Hope you guys enjoy free open-source voices from Merlin.")
        (synthesis_dir / "test_id_list.scp").write_text("test_001\ntest_002\ntest_003")
    
    # Create global_settings.cfg
    config_content = f"""
MerlinDir={merlin_dir}
WorkDir={work_dir}
Voice={voice_name}
Labels=state_align
QuestionFile=questions-radio_dnn_416.hed
Vocoder=WORLD
SamplingFreq=16000
SilencePhone='sil'
FileIDList=file_id_list.scp
Train=43
Valid=5
Test=5
ESTDIR={merlin_dir}/tools/speech_tools
FESTDIR={merlin_dir}/tools/festival
FESTVOXDIR={merlin_dir}/tools/festvox
HTKDIR={merlin_dir}/tools/bin/htk
    """
    global_config_file.write_text(config_content.strip())
    print(f"Project structure and '{global_config_file}' created.")
    return global_config_file

def extract_acoustic_features(cfg: merlin_tools.MerlinConfig):
    """
    Extracts acoustic features from wav files.
    Corresponds to: 03_prepare_acoustic_features.sh
    """
    print("\n--- Step 3: Extracting Acoustic Features ---")
    wav_dir = cfg.work_dir / "database/wav"
    feat_dir = cfg.work_dir / "database/feats"
    acoustic_data_dir = cfg.work_dir / f"experiments/{cfg.voice}/acoustic_model/data"
    
    feat_dir.mkdir(exist_ok=True)
    
    feature_script = cfg.merlin_dir / f"misc/scripts/vocoder/{cfg.vocoder.lower()}/extract_features_for_merlin.py"
    merlin_tools._run_command([
        sys.executable, str(feature_script),
        str(cfg.merlin_dir), str(wav_dir), str(feat_dir), str(cfg.sampling_freq)
    ])
    
    print("Copying features to acoustic data directory...")
    shutil.copytree(feat_dir, acoustic_data_dir, dirs_exist_ok=True)
    print("Feature extraction complete.")

def train_model(conf_file: Path, cfg: merlin_tools.MerlinConfig):
    """
    Trains a model (duration or acoustic) by calling run_merlin.py as a module.
    """
    # Add Merlin's source directory to the Python path to allow direct import
    sys.path.insert(0, str(cfg.merlin_dir / 'src'))
    try:
        import run_merlin
        run_merlin.run_wconfig(str(conf_file))
    finally:
        sys.path.pop(0) # Clean up path

def run_training_pipeline(voice_name: str, global_config_file: Path):
    """Executes the full training pipeline, steps 2-6."""
    print("\n" + "="*50)
    print("### RUNNING FULL TRAINING PIPELINE ###")
    print("="*50)
    
    cfg = merlin_tools.MerlinConfig(global_config_file)

    # Step 2: Prepare Labels
    if cfg.labels == "state_align":
        merlin_tools.run_state_alignment(global_config_file)
    elif cfg.label_type == "phone_align":
        merlin_tools.run_phone_alignment(global_config_file)
    else:
        raise ValueError(f"Unsupported label type: {cfg.labels}")
       
    # Copy labels and create file ID lists for model training
    print("Copying labels and creating file ID lists...")
    duration_data_dir = cfg.work_dir / f"experiments/{cfg.voice}/duration_model/data"
    acoustic_data_dir = cfg.work_dir / f"experiments/{cfg.voice}/acoustic_model/data"
    source_label_dir = cfg.work_dir / f"database/lab/label_{cfg.labels}"
    file_id_list_name = cfg.file_id_list
    
    file_ids = sorted([f.stem for f in source_label_dir.glob("*.lab")])
    if not file_ids:
        raise FileNotFoundError(f"No .lab files found in {source_label_dir} to create a file ID list.")
    file_id_content = "\n".join(file_ids)

    for target_dir in [duration_data_dir, acoustic_data_dir]:
        label_dest = target_dir / f"label_{cfg.labels}"
        if label_dest.exists(): shutil.rmtree(label_dest)
        shutil.copytree(source_label_dir, label_dest)
        (target_dir / file_id_list_name).write_text(file_id_content)

    print(f"'{file_id_list_name}' created successfully in model data directories.")

    # Step 3: Extract Acoustic Features
    extract_acoustic_features(cfg)

    # Step 4: Prepare Config Files for both training and synthesis
    merlin_tools.prepare_configs(global_config_file, mode="training")
    merlin_tools.prepare_configs(global_config_file, mode="synthesis")

    # Step 5: Train Duration Model
    print("\n--- Step 5: Training Duration Model ---")
    duration_conf = cfg.work_dir / f"conf/duration_{cfg.voice}.conf"
    train_model(duration_conf, cfg)
    print("Duration model training complete.")
    
    # Step 6: Train Acoustic Model
    print("\n--- Step 6: Training Acoustic Model ---")
    acoustic_conf = cfg.work_dir / f"conf/acoustic_{cfg.voice}.conf"
    train_model(acoustic_conf, cfg)
    print("Acoustic model training complete.")
    
    print("\n### TRAINING PIPELINE FINISHED SUCCESSFULLY ###")

def run_synthesis_pipeline(voice_name: str, global_config_file: Path):
    """Executes the synthesis pipeline (Step 7)."""
    print("\n" + "="*50)
    print("### RUNNING SYNTHESIS (TTS) PIPELINE ###")
    print("="*50)

    cfg = merlin_tools.MerlinConfig(global_config_file)
    synthesis_dir = cfg.work_dir / f"experiments/{voice_name}/test_synthesis"
    test_dur_conf = cfg.work_dir / f"conf/test_dur_synth_{voice_name}.conf"
    test_synth_conf = cfg.work_dir / f"conf/test_synth_{voice_name}.conf"

    # Step 7.1: Generate labels from text for synthesis
    merlin_tools.generate_labels_from_text(synthesis_dir / "txt", synthesis_dir, global_config_file, is_training=False)

    # Step 7.2: Synthesize durations
    print("\n--- Step 7.2: Synthesizing Durations ---")
    train_model(test_dur_conf, cfg)

    # Step 7.3: Synthesize speech
    print("\n--- Step 7.3: Synthesizing Speech ---")
    train_model(test_synth_conf, cfg)
    
    # Step 7.4: Clean up
    merlin_tools.clean_synthesis_files(global_config_file)

    output_wav_dir = synthesis_dir / "wav"
    print(f"\n### SYNTHESIS COMPLETE. Audio files are in: {output_wav_dir} ###")

def main():
    parser = argparse.ArgumentParser(description="A Python-based workflow manager for the Merlin TTS toolkit.")
    parser.add_argument("--voice-name", default="slt_arctic", help="Name for the voice to be built (e.g., 'slt_arctic').")
    parser.add_argument("--setup-data", action="store_true", help="Download and set up the demo voice data.")
    parser.add_argument("--train-tts", action="store_true", help="Run the full training pipeline (Steps 1-6).")
    parser.add_argument("--run-tts", action="store_true", help="Run the synthesis pipeline to generate audio from text (Step 7).")
    parser.add_argument("--run-tts-custom", action="store_true", help="Run the synthesis pipeline with custom data (Step 7).")
    parser.add_argument("--text", default="The text field should be updated", help="Text data for custom TTS")

    args = parser.parse_args()

    if not any([args.setup_data, args.train_tts, args.run_tts, args.run_tts_custom]):
        parser.error("No action requested. Please specify at least one of --setup-data, --train-tts, or --run-tts.")

    if args.run_tts_custom:
        global_config_file = setup_project(args.voice_name, test_data=args.text )
        run_synthesis_pipeline(args.voice_name, global_config_file)
        # do not continue, all done
        sys.exit(0)

    if args.setup_data:
        download_and_setup_data()
        
    global_config_file = Path.cwd() / "conf/global_settings.cfg"

    if args.train_tts:
        # Step 1 is implicitly part of the training pipeline
        global_config_file = setup_project(args.voice_name)
        run_training_pipeline(args.voice_name, global_config_file)
    
    if args.run_tts:
        if not global_config_file.exists():
            print(f"Error: Global config file not found at '{global_config_file}'.", file=sys.stderr)
            print("Please run with --train-tts first, or ensure the file exists.", file=sys.stderr)
            sys.exit(1)
        run_synthesis_pipeline(args.voice_name, global_config_file)

    print("\nAll requested tasks are done!")

if __name__ == "__main__":
    main()