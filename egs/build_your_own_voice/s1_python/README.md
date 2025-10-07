# Build Your Own Voice (Python Version)

This guide explains how to build a custom Text-to-Speech (TTS) voice using a modern, Python-based workflow that orchestrates the Merlin toolkit.

## Requirements

You need to have installed:

*   [Merlin](https://github.com/CSTR-Edinburgh/merlin#installation)
*   **Festival**: `bash tools/compile_other_speech_tools.sh`
*   **HTK**: `bash tools/compile_htk.sh`

Additionally, you need the Python scripts and libraries created in the previous steps, which should be located in your voice project directory (e.g., `egs/build_your_own_voice/s1_python`):

*   `merlin_tools.py`: A library of functions for handling core Merlin tasks.
*   `run_merlin_workflow.py`: The main orchestrator script that manages the entire voice-building process.

## Building Steps

To build your own voice, navigate to your Python project directory (e.g., `cd egs/build_your_own_voice/s1_python`) and use the main orchestrator script, `run_merlin_workflow.py`. This single, powerful script replaces the series of individual Bash scripts from the original workflow.

The script is controlled via command-line arguments, allowing you to run the entire pipeline or specific parts of it with ease.

### Orchestrating the Full Workflow

The entire voice-building process, from downloading data to training and synthesizing, can be run with a single command. The script will automatically execute all the necessary steps in the correct order.

```sh
# This command will download data, set up the project, train the models, and run synthesis
./run_merlin_workflow.py --voice-name my_voice --setup-data --train-tts --run-tts
```

### Running Individual Stages

You can also run each major stage of the pipeline independently.

#### 1. Setting up

This step downloads demo data, creates the required directory structure, and generates the main `conf/global_settings.cfg` configuration file.

```sh
# This will download and prepare the demo data
./run_merlin_workflow.py --setup-data

# The project setup is implicitly run with the training command:
./run_merlin_workflow.py --voice-name my_voice --train-tts
```
This corresponds to the original `01_setup.sh` script and parts of `run_demo_voice.sh`.

#### 2. Training the Models

This command executes the complete training pipeline, which includes label preparation, feature extraction, configuration file generation, and training the duration and acoustic models.

```sh
# This runs steps 1 through 6 of the Merlin pipeline
./run_merlin_workflow.py --voice_name my_voice --train-tts
```

This single command replaces the functionality of the following original shell scripts:
*   `01_setup.sh`
*   `02_prepare_labels.sh`
*   `03_prepare_acoustic_features.sh`
*   `04_prepare_conf_files.sh` (and its sub-scripts)
*   `05_train_duration_model.sh`
*   `06_train_acoustic_model.sh`

The Python script automatically determines the correct paths and configuration files to use for each step, leveraging the functions within the `merlin_tools.py` library.

#### 3. Synthesizing Speech

Once the models are trained, you can use this command to synthesize audio from the pre-defined test text files.

```sh
# This runs step 7 of the Merlin pipeline
./run_merlin_workflow.py --voice-name my_voice --run-tts
```
This corresponds to the original `07_run_merlin.sh` script. The synthesized audio files will be located in the `experiments/my_voice/test_synthesis/wav/` directory.

## Comprehensive Summary of the Merlin TTS Python Workflow

The provided documents detail a complete, step-by-step workflow for building a custom Text-to-Speech (TTS) voice using the Merlin toolkit. This process has been converted from a series of shell scripts into a cohesive, Python-based system orchestrated by a main script (`run_merlin_workflow.py`) and supported by a custom library (`merlin_tools.py`).

### 1. High-Level Orchestration

The entire process can be initiated and controlled by the main Python script, `run_merlin_workflow.py`, which calls functions from the `merlin_tools.py` library. The script uses command-line arguments to enable or disable major stages of the workflow.

*   **Data Setup (`--setup-data`)**: Downloads and organizes the necessary audio (`.wav`) and text (`.txt`) files into a `database` directory.
*   **Training (`--train-tts`)**: Executes the full pipeline from initial setup to training the final models.
*   **Synthesis (`--run-tts`)**: Runs the trained models to generate audio from new text.

### 2. The Seven Steps of the Merlin Workflow (Python Implementation)

The core workflow is divided into seven distinct steps, which are now implemented as functions within the Python scripts.

*   **Step 1: Project Setup (`setup_project`)**
    This initial function, called by the main orchestrator, sets up the required directory structure for a new voice project. It takes a `voice_name` as an argument and creates folders for experiments, data, models, and testing. Its most critical function is to generate the main configuration file, `conf/global_settings.cfg`, populating it with default parameters and machine-specific paths.

*   **Step 2: Label Preparation (`run_state_alignment`, `run_phone_alignment`)**
    This functionality, housed in `merlin_tools.py`, creates time-aligned phonetic labels from raw audio and text. Based on the `Labels` variable in `global_settings.cfg`, the orchestrator calls one of two functions:
    *   **State-level alignment**: Uses the HTK toolkit for more granular, sub-phonetic alignment.
    *   **Phone-level alignment**: Uses the FestVox Clustergen toolkit for phone-based alignment.
    After alignment, the orchestrator script copies the generated labels and creates a `file_id_list.scp` in the respective data directories for the duration and acoustic models.

*   **Step 3: Acoustic Feature Extraction (`extract_acoustic_features`)**
    This function processes the raw `.wav` files to extract acoustic features. It uses a specified vocoder (e.g., WORLD, STRAIGHT) and calls a Merlin Python script to perform the extraction, saving the features before copying them to the acoustic model's data folder.

*   **Step 4: Configuration File Preparation (`prepare_training_configs`, `prepare_synthesis_configs`)**
    This functionality is handled by functions in `merlin_tools.py` that generate the detailed configuration files (`.conf`) required for training and synthesis.
    *   `prepare_training_configs`: Creates `duration_<voice>.conf` and `acoustic_<voice>.conf` for training.
    *   `prepare_synthesis_configs`: Creates specialized `.conf` files for synthesis, with flags set to generate audio rather than train a model.
    These functions replace the original method of using `sed` with robust, in-memory string and regex substitution.

*   **Step 5 & 6: Model Training (`train_model`)**
    A single helper function, `train_model`, is used to train both the duration and acoustic models. It takes the appropriate configuration file and calls Merlin's main training script, `run_merlin.py`, as a direct Python module import.

*   **Step 7: Synthesis (`run_synthesis_pipeline`)**
    This function performs text-to-speech synthesis by orchestrating a series of sub-tasks:
    1.  Generates linguistic labels from text using the `generate_labels_from_text` function.
    2.  Runs the trained duration and acoustic models via the `train_model` function.
    3.  Synthesizes a `.wav` file from the features.
    4.  Cleans up intermediate files using the `clean_synthesis_files` function.

### 3. Utility and Portability Libraries

*   **Path Conversion**: The original `convert_paths.sh` script, designed to make projects portable, has been deprecated. Its functionality is now integrated into the Python workflow, which dynamically generates correct paths, or is handled by the self-configuring `forced_alignment.py` script.
*   **Configuration Management (`merlin_tools.MerlinConfig`)**: A new helper class within `merlin_tools.py` loads the `global_settings.cfg` once and provides clean, typed access to all parameters throughout the workflow, improving code readability and reducing redundant file operations.