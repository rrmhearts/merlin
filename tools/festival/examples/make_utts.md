## make_utts

This script, `make_utts`, is a Festival utility designed to perform the reverse operation of `dumpfeats`. Its primary purpose is to **construct a complete Festival Utterance file (`.utt`) by "stitching" together multiple, separate label files** that each represent a different linguistic tier or relation (e.g., segments, syllables, words).

This is a critical step in speech database creation and in certain analysis-synthesis workflows, where linguistic information is often created or annotated in separate, time-aligned files.

### What `make_utts` Does: A High-Level Overview

1.  **Input**: It takes a collection of simple, time-aligned label files as input. These files are typically organized into subdirectories named after the relation they represent (e.g., `Segment/`, `Word/`, `Syllable/`).
2.  **Processing**: It reads each of these individual label files and loads them as separate relations within a new, empty utterance.
3.  **Structure Building**: The script's main job is to then build the hierarchical links *between* these flat lists of items. For example, it determines which `Segment` items belong to which `Syllable` items, and which `Syllable` items belong to which `Word` items, creating the complete tree-like Utterance Structure.
4.  **Output**: It saves the final, fully-structured utterance to a single `.utt` file in a specified output directory.

In short, `make_utts` turns this:

*   `file01.Segment` (a list of phonemes and their timings)
*   `file01.Syllable` (a list of syllables and their timings)
*   `file01.Word` (a list of words and their timings)

...into this:

*   `file01.utt` (a single, structured file where phonemes are correctly grouped under syllables, which are grouped under words, etc.)

### How the Script Works

The script is a Festival Scheme program cleverly disguised as a shell script.
*   **The Header**: The first two lines (`#!/bin/sh` and `"true" ; exec ...`) are a standard trick to make the shell execute the Festival binary, which then runs the rest of the file as a Scheme script.
*   **Initialization**: It loads Festival's initial configuration and defines default variables for directory paths and processing options.
*   **Option Parsing (`get_options`)**: It parses command-line arguments like `-label_dir` (where to find the input label files) and `-utt_dir` (where to save the output `.utt` files).
*   **Core Function (`make_utt`)**: This is the main worker function. For each base filename provided, it:
    *   Loads all the corresponding relation files (e.g., `my_file.Segment`, `my_file.Word`).
    *   Calls helper functions to build the hierarchy:
        *   `make_syl_structure`: Groups `Segments` into `Syllables` and `Syllables` into `Words`.
        *   `make_phrase_structure`: Groups `Words` into `Phrases`.
        *   `intevent_link_syls`: Links `Intonation Events` to the `Syllables` they occur in.
        *   `make_target_links`: Links F0 `Targets` to the `Segments` they fall within.
*   **Saving the Utterance**: Finally, it calls `utt.save` to write the complete utterance object to a `.utt` file.

### Key Command-Line Options

The help text within the script defines the most important options:

*   `-utt_dir <string>`: Specifies the directory where the output `.utt` files will be saved. Defaults to `festival/utts/`.
*   `-label_dir <string>`: Specifies the root directory containing the subdirectories of label files (e.g., `Segment/`, `Word/`). Defaults to `festival/relations/`.
*   `-tilt_events`: A special flag to handle intonation events created by the "Tilt" model, which requires a specific way of linking events to syllables.
*   `-pos`: Tells the script to run a Part-of-Speech tagger on the newly constructed utterance.
*   `<file1.Segment> [file2.Segment ...]`: The arguments to the script are a list of files from one of the relations (typically `Segment`), from which the base filenames are extracted. For example, if you provide `festival/relations/Segment/file01.Segment`, the script will look for `file01` in all other relation subdirectories.