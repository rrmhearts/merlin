# Festival

Festival is a powerful, open-source speech synthesis (Text-to-Speech) system developed at the University of Edinburgh. It provides a comprehensive framework for building and researching speech synthesis systems. For developers and researchers looking to customize, extend, or simply understand the inner workings of Festival, a deep dive into its source code is essential. The following guide breaks down the directory structure of the Festival distribution, explaining the purpose of each component and how they fit together. 
An [Integration Guide](../../docs/FESTIVAL.md) is available for potentially using system festival (`/usr/bin/festival`) in place of the locally compiled version but it is not currently recommended. The recommended method is to use the `./install.sh` script.


- [Festival](#festival)
  - [Introduction to Frontend](#introduction-to-frontend)
  - [The Source Code](#the-source-code)
  - [Original Readme](#original-readme)

## Introduction to Frontend

In a Text-to-Speech (TTS) system like Festival, the process of converting text to audio is broadly divided into two major stages: the "front-end" and the "back-end." The front-end is responsible for all the linguistic analysis that happens before any sound is generated. Its job is to take raw, unstructured text and transform it into a detailed linguistic and prosodic specification that the back-end can use to synthesize the final waveform.

Within Festival, this front-end processing is a highly modular and customizable pipeline. The central data structure that is built and enriched throughout this process is the **Utterance Structure**. Each module in the front-end pipeline takes the Utterance Structure as input, adds a new layer of information to it, and passes it to the next module.

Drawing from the Festival manual, the typical sequence of front-end processing steps includes:

1.  **Text Analysis:** The process begins with tokenization, where the input text is broken down into a list of tokens, including words, numbers, punctuation, and whitespace. Festival's text modes handle different input formats (e.g., plain text, SGML) and perform text normalization, which involves expanding abbreviations, dates, and numbers into their full word forms (e.g., "1984" becomes "nineteen eighty-four").

2.  **Part of Speech (POS) Tagging:** Each word token is assigned a grammatical category, such as noun, verb, or adjective. This step is crucial, as a word's pronunciation and the overall sentence prosody often depend on its grammatical function (e.g., the noun "a **rec**ord" vs. the verb "to re**cord**").

3.  **Pronunciation Assignment:** The system looks up each word in a **lexicon** to find its corresponding sequence of phonemes. For words not found in the lexicon (out-of-vocabulary words), Festival employs a set of **Letter-to-Sound (LTS) rules** to predict a plausible pronunciation.

4.  **Prosody Prediction:** This is where the "melody" and "rhythm" of the speech are determined. The two key components of this stage are:
    *   **Intonation:** An intonation model predicts the pitch contour (F0) across the utterance, creating a more natural and expressive melody.
    *   **Duration:** A duration model assigns a specific time length to each phoneme in the utterance, controlling the pace and rhythm of the speech.

At the conclusion of the front-end process, the simple input string has been transformed into a rich Utterance Structure containing phonemes, timing information, and pitch targets. This detailed specification is then passed to the back-end synthesizer (e.g., UniSyn or a unit selection engine) to generate the final, audible speech.

## The Source Code

The ultimate authority on what happens in the system lies in the source code itself. No matter how hard we try, and how automatic we make it, the source code will always be ahead of the documentation. Thus if you are going to be using Festival in a serious way, familiarity with the source is essential.

The lowest level functions are catered for in the Edinburgh Speech Tools, a separate library distributed with Festival. The Edinburgh Speech Tool Library offers the basic utterance structure, waveform file access, and other various useful low-level functions which we share between different speech systems in our work. See (speechtools)Top section ‘Overview’ in *Edinburgh Speech Tools Library Manual*.

The directory structure for the Festival distribution reflects the conceptual split in the code.

*   `./bin/`
    The user-level executable binaries and scripts that are part of the festival system. These are simple symbolic links to the binaries or if the system is compiled with shared libraries small wrap-around shell scripts that set `LD_LIBRARY_PATH` appropriately.

*   `./doc/`
    This contains the texinfo documentation for the whole system. The `Makefile` constructs the info and/or html version as desired. Note that the `festival` binary itself is used to generate the lists of functions and variables used within the system, so must be compiled and in place to generate a new version of the documentation.

*   `./examples/`
    This contains various examples. Some are explained within this manual, others are there just as examples.

*   `./lib/`
    The basic Scheme parts of the system, including `init.scm` the first file loaded by `festival` at start-up time. Depending on your installation, this directory may also contain subdirectories containing lexicons, voices and databases. This directory and its sub-directories are used by Festival at run-time.

*   `./lib/etc/`
    Executables for Festival’s internal use. A subdirectory containing at least the audio spooler will be automatically created (one for each different architecture the system is compiled on). Scripts are added to this top level directory itself.

*   `./lib/voices/`
    By default this contains the voices used by Festival including their basic Scheme set up functions as well as the diphone databases.

*   `./lib/dicts/`
    This contains various lexicon files distributed as part of the system.

*   `./config/`
    This contains the basic `Makefile` configuration files for compiling the system (run-time configuration is handled by Scheme in the `lib/` directory). The file `config/config` created as a copy of the standard `config/config-dist` is the installation specific configuration. In most cases a simple copy of the distribution file will be sufficient.

*   `./src/`
    The main C++/C source for the system.
    *   `./src/lib/`
        Where the `libFestival.a` is built.
    *   `./src/include/`
        Where include files shared between various parts of the system live. The file `festival.h` provides access to most of the parts of the system.
    *   `./src/main/`
        Contains the top level C++ files for the actual executables. This is directory where the executable binary `festival` is created.
    *   `./src/arch/`
        The main core of the Festival system. At present everything is held in a single sub-directory `./src/arc/festival/`. This contains the basic core of the synthesis system itself. This directory contains lisp front ends to access the core utterance architecture, and phonesets, basic tools like, client/server support, ngram support, etc, and an audio spooler.
    *   `./src/modules/`
        In contrast to the `arch/` directory this contains the non-core parts of the system. A set of basic example modules are included with the standard distribution. These are the parts that do the synthesis, the other parts are just there to make module writing easier.
        *   `./src/modules/base/`
            This contains some basic simple modules that weren’t quite big enough to deserve their own directory. Most importantly it includes the `Initialize` module called by many synthesis methods which sets up an utterance structure and loads in initial values. This directory also contains phrasing, part of speech, and word (syllable and phone construction from words) modules.
        *   `./src/modules/Lexicon/`
            This is not really a module in the true sense (the `Word` module is the main user of this). This contains functions to construct, compile, and access lexicons (entries of words, part of speech and pronunciations). This also contains a letter-to-sound rule system.
        *   `./src/modules/Intonation/`
            This contains various intonation systems, from the very simple to quite complex parameter driven intonation systems.
        *   `./src/modules/Duration/`
            This contains various duration prediction systems, from the very simple (fixed duration) to quite complex parameter driven duration systems.
        *   `./src/modules/UniSyn/`
            A basic diphone synthesizer system, supporting a simple database format (which can be grouped into a more efficient binary representation). It is multi-lingual, and allows multiple databases to be loaded at once. It offers a choice of concatenation methods for diphones: residual excited LPC or PSOLA™ (which is not distributed).
        *   `./src/modules/Text/`
            Various text analysis functions, particularly the tokenizer and utterance segmenter (from arbitrary files). This directory also contains the support for text modes and SGML.
        *   `./src/modules/donovan/`
            An LPC based diphone synthesizer. Very small and neat.
        *   `./src/modules/rxp/`
            The Festival/Scheme front end to an XML parser written by Richard Tobin from University of Edinburgh’s Language Technology Group. rxp is now part of the speech tools rather than just Festival.
        *   `./src/modules/parser`
            A simple interface to the Stochastic Context Free Grammar parser in the speech tools library.
        *   `./src/modules/diphone`
            An optional module containing the previously used diphone synthesizer.
        *   `./src/modules/clunits`
            A partial implementation of a cluster unit selection algorithm as described in `black97c`.
        *   `./src/modules/Database rjc_synthesis`
            This consists of a new set of modules for doing waveform synthesis. They are intended to be unit size independent (e.g. diphone, phone, non-uniform unit). Also selection, prosodic modification, joining and signal processing are separately defined. Unfortunately this code has not really been exercised enough to be considered stable to be used in the default synthesis method, but those working on new synthesis techniques may be interested in integration using these new modules. They may be updated before the next full release of Festival.
        *   `./src/modules/*`
            Other optional directories may be contained here containing various research modules not yet part of the standard distribution. See below for descriptions of how to add modules to the basic system.

One intended use of Festival is to offer a software system where new modules may be easily tested in a stable environment. We have tried to make the addition of new modules easy, without requiring complex modifications to the rest of the system.

## Original Readme

              The Festival Speech Synthesis System
                   version 2.5.1 July 2020

https://github.com/festvox/festival/

This directory contains the Festival Speech Synthesis System,
developed at CSTR, University of Edinburgh. The project was originally
started by Alan W Black and Paul Taylor but many others have been
involved (see ACKNOWLEDGEMENTS file for full list).

Festival offers a general framework for building speech synthesis
systems as well as including examples of various modules.  As a whole
it offers full text to speech through a number APIs: from shell level,
though a Scheme command interpreter, as a C++ library, and an Emacs
interface.  Festival is multi-lingual (currently English (US and UK)
and Spanish are distributed but a host of other voices have been
developed by others) though English is the most advanced.

The system is written in C++ and uses the Edinburgh Speech Tools
for low level architecture and has a Scheme (SIOD) based command
interpreter for control.  Documentation is given in the FSF texinfo
format which can generate, a printed manual, info files and HTML.

COPYING

Festival is free.  Earlier versions were restricted to non-commercial
use but we have now relaxed those conditions.  The licence is an X11
style licence thus it can be incorporated in commercial products
and free source products without restriction.  See COPYING for the
actual details.

INSTALL

Festival should run on any standard Unix platform.  It has already run
on Solaris, SunOS, Linux and FreeBSD.  It requires a C++ compiler (GCC
2.7.2, 2.8.1, 2.95.[123], 3.2.3 3.3.2 RedHat "gcc-2.96", gcc 3.3, gcc
4.4.x and gcc-4.5.x, gcc-6.2.0 are our standard compilers) to
install. A port to Windows XP/NT/95/98 and 2000 using either Cygnus
GNUWIN32, this is still new but many people are successfully using it,
it works fine with Windows 10 bash

A detailed description of installation and requirements for the whole
system is given in the file INSTALL read that for details.

NEWS

Keep abreast of Festival News by regularly checking the Festival homepage
   http://www.cstr.ed.ac.uk/projects/festival/
or the US site
   http://festvox.org/festival/
or on github
   https://github.com/festvox/festival/

New in Festival 2.5
   Support for gcc6 (which is a somewhat different dialect of C++)

New in Festival 2.2
   updates to hts (hts_engine 1.07) and clustergen

New in Festival 2.1
   Support for various new GCC compilers
   Improved support for hts, clustergen, clunits and multisyn voices
   lots of wee bugs fixed
