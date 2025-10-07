## make_labels

This shell script, `make_labels`, is a crucial utility in a typical Merlin/HTS-style speech synthesis training pipeline. Its primary purpose is to **automate the batch-generation of two different types of label files (`.lab`) from a directory of Festival utterance files (`.utt`)**.

These two types of labels, **monophone** and **full-context**, are essential for training the different components of a statistical or neural speech synthesis model.

### High-Level Goal

The script takes a directory of pre-processed utterance files and, for each one, produces two corresponding label files:
1.  A **full-context label** (e.g., `full/file01.lab`) containing a rich, detailed description of each phoneme's linguistic context.
2.  A **monophone label** (e.g., `mono/file01.lab`) containing a simplified, context-independent description of each phoneme.

### Step-by-Step Workflow

For every `.utt` file it finds, the script performs the following sequence of operations:

1.  **Extract Full Feature Set**: It calls Festival's `dumpfeats` utility.
    *   It uses both `extra_feats.scm` and `label.feats` to define a comprehensive set of linguistic features to extract for each `Segment` (phoneme).
    *   The raw output, containing all the extracted features, is saved to a temporary file named `tmp`.

2.  **Generate Full-Context Labels**: It then processes the `tmp` file using the `gawk` text-processing utility, driven by the `label-full.awk` script.
    *   This AWK script formats the raw feature data into the specific "full-context" format required by HTS/Merlin. This format typically includes the phoneme's identity surrounded by a rich set of features describing its phonetic, syllabic, and prosodic environment.
    *   The result is saved in the `full/` subdirectory (e.g., `labels/full/my_utterance.lab`).

3.  **Generate Monophone Labels**: It processes the *same* `tmp` file again with `gawk`, but this time using the `label-mono.awk` script.
    *   This AWK script extracts only the essential information (usually just the phoneme's name) and formats it into a simpler "monophone" label.
    *   The result is saved in the `mono/` subdirectory (e.g., `labels/mono/my_utterance.lab`).

4.  **Loop and Clean Up**: The script repeats this process for every `.utt` file in the input directory and deletes the temporary `tmp` file when it's finished.

### Inputs and Outputs

The script requires four command-line arguments to run:

1.  `labels_dir`: The top-level output directory where the `mono/` and `full/` subdirectories will be created and populated with the new `.lab` files.
2.  `utts_dir`: The input directory containing the Festival utterance files (`.utt`) to be processed.
3.  `dumpfeats`: The full path to the `dumpfeats` executable.
4.  `scripts`: The directory containing the necessary helper scripts:
    *   `extra_feats.scm`: The custom feature library for Festival.
    *   `label.feats`: The main feature definition file for `dumpfeats`.
    *   `label-full.awk`: The AWK script for creating full-context labels.
    *   `label-mono.awk`: The AWK script for creating monophone labels.

### Why Are Two Types of Labels Needed?

*   **Monophone Labels (`mono/`)**: These are used for the initial bootstrapping and training of basic acoustic models. They help the system learn the fundamental sound of each phoneme in isolation. They are also often used for forced alignment, where a speech recognizer aligns the audio with a known phonetic transcription.

*   **Full-Context Labels (`full/`)**: These are the core input for training the final, high-quality acoustic and duration models. The rich contextual information allows the system to learn the complex variations of a phoneme's sound and timing based on its environment (co-articulation, stress, position, etc.). This is what enables the final synthesized speech to sound natural and fluid.

In summary, **`make_labels` is a data preparation script that orchestrates `dumpfeats` and `awk` to transform linguistic information from Festival utterances into the specific label formats required to train a Merlin/HTS speech synthesis system.**