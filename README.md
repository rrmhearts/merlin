## Merlin: The Neural Network (NN) based Speech Synthesis System

This repository contains the Neural Network (NN) based Speech Synthesis System developed at the Centre for Speech Technology Research (CSTR), University of Edinburgh.

Merlin is a toolkit for building Deep Neural Network models for statistical parametric speech synthesis. It must be used in combination with a front-end text processor (e.g., Festival) and a vocoder (e.g., STRAIGHT or WORLD).

The system is written in Python and relies on Keras and TensorFlow. Merlin comes with recipes (in the spirit of the [Kaldi](https://github.com/kaldi-asr/kaldi) automatic speech recognition toolkit) to show you how to build state-of-the art systems.

Merlin is free software, distributed under an Apache License Version 2.0, allowing unrestricted commercial and non-commercial use alike.

Read the documentation at [cstr-edinburgh.github.io/merlin](https://cstr-edinburgh.github.io/merlin/).

**Note:** This repository is a fork.  The original repository is located at [https://github.com/CSTR-Edinburgh/merlin](https://github.com/CSTR-Edinburgh/merlin). This fork contains updates and modifications; refer to the commit history and any open pull requests for details on changes made.

Merlin is compatible with: __Python 3.10__ (See notes below).

Installation
------------
Merlin uses the following dependencies:

-   python >= 3.8 (ideally 3.10)
-   Keras >= 3.X
- tensorflow (optional, required if you use tensorflow models)
- pytorch (optional, required if you use torch models)
- sklearn, scipy, h5py (optional, required if you use keras models)

To install Merlin, `cd` merlin and run the below steps:

-   **Create a virtual environment (recommended):**
    ```sh
    python3 -m venv .venv
    source .venv/bin/activate
    ```

-   **Install dependencies:**
    ```sh
    bash ./install.sh
    pip install -r requirements.txt # if something is missing
    ```

For detailed instructions, to build the toolkit: see [INSTALL](https://github.com/rrmhearts/merlin/blob/master/INSTALL.md) and [CSTR blog post](https://cstr-edinburgh.github.io/install-merlin/).  
These instructions are valid for UNIX systems including various flavors of Linux;

**Important Notes on Python and TensorFlow:**

*   Due to the rapid evolution of TensorFlow and its compatibility with various Python versions, it's crucial to use compatible versions.  The officially supported Python versions for this fork are 3.8-3.10.  Later versions *might* work, but are not guaranteed.
*   TensorFlow versions prior to 2.0 are **not** supported.
*   If you encounter issues, double-check your Python and TensorFlow versions.
*   Consider using a virtual environment to manage dependencies and avoid conflicts.

Getting started with Merlin
---------------------------

To run the example system builds, see `egs/README.txt`

As a first demo, please follow the scripts in `egs/slt_arctic` or `egs/build_your_own_voice/s1[_python]`

Now, you can also follow Josh Meyer's [blog post](http://jrmeyer.github.io/tts/2017/02/14/Installing-Merlin.html) for detailed instructions on how to install Merlin and build SLT demo voice (This blog post might be outdated, use with caution).

For a more in-depth tutorial about building voices with Merlin, you can check out:

*   [Deep Learning for Text-to-Speech Synthesis, using the Merlin toolkit (Interspeech 2017 tutorial)](http://www.speech.zone/courses/one-off/merlin-interspeech2017)
*   [Arctic voices](https://cstr-edinburgh.github.io/merlin/getting-started/slt-arctic-voice)
*   [Build your own voice](https://cstr-edinburgh.github.io/merlin/getting-started/build-own-voice)

Synthetic speech samples
------------------------

Listen to [synthetic speech samples](https://cstr-edinburgh.github.io/merlin/demo.html) from our SLT arctic voice.

Development pattern for contributors
------------------------------------

1.  [Create a personal fork](https://help.github.com/articles/fork-a-repo/) of the [main Merlin repository](https://github.com/CSTR-Edinburgh/merlin) in GitHub.
2.  Make your changes in a named branch different from `master`, e.g. you create a branch `my-new-feature`.
3.  [Generate a pull request](https://help.github.com/articles/creating-a-pull-request/) through the Web interface of GitHub.

**Important Considerations for this Fork:**

*   Contribute to this fork similarly at [this repository](https://github.com/rrmhearts/merlin)!
*   Before submitting pull requests, ensure that your changes are compatible with the changes introduced in this fork. Carefully review the commit history and any open pull requests.
*   Specify clearly in your pull request description the purpose of your changes and how they relate to the original repository and this fork.

Contact Us
----------

Post your questions, suggestions, and discussions to [GitHub Issues](https://github.com/CSTR-Edinburgh/merlin/issues).  For issues related to this specific fork, use this repo or contact [rrmhearts](https://github.com/rrmhearts) and please clearly indicate that in your issue title or description.

Citation
--------

If you publish work based on Merlin, please cite:

Zhizheng Wu, Oliver Watts, Simon King, "[Merlin: An Open Source Neural Network Speech Synthesis System](https://isca-speech.org/archive/SSW_2016/pdfs/ssw9_PS2-13_Wu.pdf)" in Proc. 9th ISCA Speech Synthesis Workshop (SSW9), September 2016, Sunnyvale, CA, USA.